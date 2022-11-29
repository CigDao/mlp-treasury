import Prim "mo:prim";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import TrieMap "mo:base/TrieMap";
import List "mo:base/List";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Http "../helpers/http";
import Utils "../helpers/Utils";
import JSON "../helpers/JSON";
import Constants "../Constants";
import Response "../models/Response";
import Round "./models/Round";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Trie "mo:base/Trie";
import TokenService "../services/TokenService";
import WICPService "../services/WICPService";
import CommunityService "../services/CommunityService";
import CansiterService "../services/CansiterService";
import TreasuryService "../services/TreasuryService";
import ControllerService "../services/ControllerService";

actor class Distribution(_owner:Principal) = this {

    private let roundTime:Nat = 86400000000000;
    //private let roundTime:Nat = 60000000000;
    private stable var lastRoundEnd:Int = 0;
    private stable var tokensPerRound:Nat = 0;
    private stable var start:Int = 0;
    private stable var lastRound:Nat = 0;
    private let disitribtionPercentage:Float = 0.2;
    private stable var isStart = false;

    private type ErrorMessage = { #message : Text;};
    private type JSON = JSON.JSON;
    private type ApiError = Response.ApiError;
    private type Round = Round.Round;

    private stable var roundEntries : [(Nat32,Trie.Trie<Principal, Round>)] = [];
    private var rounds = HashMap.fromIter<Nat32,Trie.Trie<Principal, Round>>(roundEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

    private stable var roundSizeEntries : [(Nat32,Nat)] = [];
    private var roundSize = HashMap.fromIter<Nat32,Nat>(roundSizeEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

    private stable var claimedRoundEntries : [(Nat32,[Principal])] = [];
    private var claimedRounds = HashMap.fromIter<Nat32,[Principal]>(claimedRoundEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

    system func preupgrade() {
        roundEntries := Iter.toArray(rounds.entries());
        roundSizeEntries := Iter.toArray(roundSize.entries());
    };

    system func postupgrade() {
        roundEntries := [];
        roundSizeEntries := [];
    };

    /*system func heartbeat() : async () {
        let now = Time.now();
        let elapsed = now - lastRoundEnd;
        if(elapsed > roundTime and roundId <= lastRound) {
            lastRoundEnd := now;
            roundId := roundId + 1;
        };
    };*/

    public query func getMemorySize(): async Nat {
        let size = Prim.rts_memory_size();
        size;
    };

    public query func getHeapSize(): async Nat {
        let size = Prim.rts_heap_size();
        size;
    };

    public query func getCycles(): async Nat {
        Cycles.balance();
    };

    private func _getMemorySize(): Nat {
        let size = Prim.rts_memory_size();
        size;
    };

    private func _getHeapSize(): Nat {
        let size = Prim.rts_heap_size();
        size;
    };

    private func _getCycles(): Nat {
        Cycles.balance();
    };

    public shared({caller}) func startDistribution(_lastRound:Nat): async () {
        assert(_owner == caller);
        assert(isStart == false);
        isStart := true;
        lastRound :=_lastRound;
        let supply = await _tokenSupply();
        let distributionSupply = Float.mul(Utils.natToFloat(supply), disitribtionPercentage);
        tokensPerRound :=  Nat.div(Utils.floatToNat(distributionSupply),_lastRound);
        start := Time.now();
    };

    public shared({caller}) func claim(round:Nat32): async TokenService.TxReceipt {
        let isClaimed = _isClaimed(round, caller);
        let endOfRound:Int = roundTime * Nat32.toNat(round) + start;
        let now = Time.now();
        if(now < endOfRound or isClaimed){
            return #Err(#Unauthorized);
        };
        let key = { hash = Principal.hash(caller); key = caller};
        let exist = rounds.get(round);
        switch(exist){
            case(?exist){
                let roundObject = Trie.get<Principal, Round>(exist,key,Principal.equal);
                switch(roundObject){
                    case(?roundObject){
                        _setClaimed(round, caller);
                        let total = _roundTotal(round);
                        let payout = roundPayout(Utils.natToFloat(total),Utils.natToFloat(roundObject.deposit));
                        //transfer amount 
                        ignore await TokenService.transfer(caller,Utils.floatToNat(payout));
                        let recieved = Utils.floatToNat(payout);
                        #Ok(recieved);
                    };
                    case(null){
                        return #Err(#Unauthorized);
                    };
                };
            };
            case(null){
                return #Err(#Unauthorized);
            }
        };
    };

    public shared({caller}) func deposit(roundId:Nat32,amount:Nat): async WICPService.TxReceipt {
        let isEnd = _isEnd(roundId);
        if(isEnd == false){
           return #Err(#Unauthorized);
        };
        assert(amount > 0);
        let spender = Principal.fromActor(this);
        let treasury = Principal.fromText(Constants.treasuryCanister);
        let allowance = await WICPService.canister.allowance(caller,spender);
        if(allowance < amount){
            return #Err(#InsufficientAllowance);
        };
        let result = await WICPService.canister.transferFrom(caller,treasury,amount);
        let key = { hash = Principal.hash(caller); key = caller};
        switch(result){
            case(#Ok(value)){
                let exist = rounds.get(roundId);
                switch(exist){
                    //checks if round exist
                    case(?exist) {
                        //check if principal already exist for the round
                        let roundObject = Trie.get<Principal, Round>(exist,key,Principal.equal);
                        switch(roundObject){
                            case(?roundObject){
                                let round = {
                                    id = roundId;
                                    holder = caller;
                                    deposit = roundObject.deposit + amount;
                                    recieved = 0;
                                };

                                let _temp = Trie.put<Principal, Round>(exist,key,Principal.equal,round).0;
                                rounds.put(roundId,_temp);
                                _addToRound(roundId, amount);
                            };
                            case(null){
                                let round = {
                                    id = roundId;
                                    holder = caller;
                                    deposit = amount;
                                    recieved = 0;
                                };

                                let _temp = Trie.put<Principal, Round>(exist,key,Principal.equal,round).0;
                                rounds.put(roundId,_temp);
                                _addToRound(roundId, amount);
                            };
                        };
                    };
                    case(null){
                        let round = {
                            id = roundId;
                            holder = caller;
                            deposit = amount;
                            recieved = 0;
                        };

                        let _temp = Trie.put<Principal, Round>(Trie.empty(),key,Principal.equal,round).0;
                        rounds.put(roundId,_temp);
                        _addToRound(roundId, amount);
                    };
                };
            };
            case(#Err(value)){
               
            };
        };

        result;
    };

    /*public shared({caller}) func realICPDeposit(roundId:Nat32,amount:Nat): async WICPService.TxReceipt {
        let isEnd = _isEnd(roundId);
        if(isEnd == false){
           return #Err(#Unauthorized);
        };
        assert(amount > 0);
        let spender = Principal.fromActor(this);
        let allowance = await WICPService.canister.allowance(caller,spender);
        if(allowance < amount){
            return #Err(#InsufficientAllowance);
        };
        let result = await WICPService.canister.transferFrom(caller,spender,amount);
        let key = { hash = Principal.hash(caller); key = caller};
        switch(result){
            case(#Ok(value)){
                ignore await WICPService.canister.transfer(caller,amount);
                let exist = rounds.get(roundId);
                switch(exist){
                    //checks if round exist
                    case(?exist) {
                        //check if principal already exist for the round
                        let roundObject = Trie.get<Principal, Round>(exist,key,Principal.equal);
                        switch(roundObject){
                            case(?roundObject){
                                let round = {
                                    id = roundId;
                                    holder = caller;
                                    deposit = roundObject.deposit + amount;
                                    recieved = 0;
                                };

                                let _temp = Trie.put<Principal, Round>(exist,key,Principal.equal,round).0;
                                rounds.put(roundId,_temp);
                                _addToRound(roundId, amount);
                            };
                            case(null){
                                let round = {
                                    id = roundId;
                                    holder = caller;
                                    deposit = amount;
                                    recieved = 0;
                                };

                                let _temp = Trie.put<Principal, Round>(exist,key,Principal.equal,round).0;
                                rounds.put(roundId,_temp);
                                _addToRound(roundId, amount);
                            };
                        };
                    };
                    case(null){
                        let round = {
                            id = roundId;
                            holder = caller;
                            deposit = amount;
                            recieved = 0;
                        };

                        let _temp = Trie.put<Principal, Round>(Trie.empty(),key,Principal.equal,round).0;
                        rounds.put(roundId,_temp);
                        _addToRound(roundId, amount);
                    };
                };
            };
            case(#Err(value)){
               
            };
        };

        result;
    };*/

    private func _isEnd(round:Nat32): Bool {
        let endTime = start + (Nat32.toNat(round) * roundTime);
        endTime > Time.now();
    };

    private func _tokenSupply(): async Nat {
        await TokenService.totalSupply();
    };

    private func _addToRound(round:Nat32, amount:Nat) {
        let exist = roundSize.get(round);
        switch(exist){
            case(?exist){
                let _amount = exist + amount;
                roundSize.put(round,_amount);
            };
            case(null){
                roundSize.put(round,amount);
            };
        };
    };

    private func _roundTotal(round:Nat32): Nat {
        var amount:Nat = 0;
        let exist = roundSize.get(round);
        switch(exist){
            case(?exist){
                return exist;
            };
            case(null){
                return 0;
            };
        };
    };

    private func _setClaimed(round:Nat32, principal:Principal) {
        let exist = claimedRounds.get(round);
        switch(exist){
            case(?exist){
                let calimed = Array.append(exist,[principal]);
                claimedRounds.put(round,calimed);
            };
            case(null) {
                claimedRounds.put(round,[principal]);
            };
        };
    };

    private func _isClaimed(round:Nat32, principal:Principal): Bool {
        let exist = claimedRounds.get(round);
        switch(exist){
            case(?exist){
                let calimed = Array.find(exist,func (e:Principal):Bool{e == principal});
                switch(calimed){
                    case(?calimed){
                        return true;
                    };
                    case(null){
                        return false;
                    };
                };
            };
            case(null) {
                return false;
            };
        };
    };

    private func roundPayout(total:Float,deposit:Float): Float {
        let percentage = deposit/total;
        Utils.natToFloat(tokensPerRound)*percentage
    };

    public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));

        if (path.size() == 1) {
            switch (path[0]) {
                case ("fetchRounds") return _fetchRoundsResponse();
                case ("getLastRound") return _natResponse(lastRound);
                case ("getTokensPerRound") return _natResponse(tokensPerRound);
                case ("getStart") {
                    let nat64 = Nat64.fromIntWrap(start);
                    return _natResponse(Nat64.toNat(nat64));
                };
                case ("getRoundTime") return _natResponse(roundTime);
                case (_) return return Http.BAD_REQUEST();
            };
        } else if (path.size() == 2) {
            switch (path[0]) {
                case ("fetchRound") return _fetchRoundResponse(Utils.textToNat32(path[1]));
                case ("fetchRoundsByPrincipal") return _fetchRoundsByPrincipalResponse(Principal.fromText(path[1]));
                case ("fetchClaimedRounds") return _fetchClaimedRoundsResponse(Principal.fromText(path[1]));
                case (_) return return Http.BAD_REQUEST();
            };
        }else {
            return Http.BAD_REQUEST();
        };
    };

    private func _natResponse(value : Nat): Http.Response {
        let json = #Number(value);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response: Http.Response = {
            status_code        = 200;
            headers            = [("Content-Type", "application/json")];
            body               = blob;
            streaming_strategy = null;
        };
    };

    private func _fetchClaimedRounds(caller:Principal): [Nat32] {
        var results:[Nat32] = [];
        for ((id,principals) in claimedRounds.entries()) {
            let exist = Array.find(principals,func(e:Principal):Bool {e == caller});
            switch(exist){
                case(?exist){
                    results := Array.append(results,[id]);
                };
                case(null){

                };
            };
        };
        results;
    };

    private func _fetchClaimedRoundsResponse(caller:Principal): Http.Response {
        let _rounds = _fetchClaimedRounds(caller);
        var result:[JSON] = [];
        for(id in _rounds.vals()) {
            result := Array.append(result,[#Number(Nat32.toNat(id))]);
        };
        let json = #Array(result);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _fetchRounds(): [Round] {
        var results:[Round] = [];
        for ((id,round) in rounds.entries()) {
            let _rounds = Iter.toArray(Trie.iter<Principal, Round>(round));
            for ((id,deposit) in _rounds.vals()) {
                results := Array.append(results,[deposit]);
            };
        };
        results;
    };

    private func _fetchRoundsByPrincipal(principal:Principal): [Round] {
        var results:[Round] = [];
        for ((id,round) in rounds.entries()) {
            let _rounds = Iter.toArray(Trie.iter<Principal, Round>(round));
            for ((id,deposit) in _rounds.vals()) {
                if(deposit.holder == principal){
                    results := Array.append(results,[deposit]);
                };
            };
        };
        results;
    };

    private func _fetchRoundsResponse() : Http.Response {
        let _map : HashMap.HashMap<Nat32, Nat> = HashMap.HashMap<Nat32, Nat>(
            0,
            Nat32.equal,
            func (a : Nat32) : Nat32 {a},
        );
        let _rounds =  _fetchRounds();
        var result:[JSON] = [];

        for(_round in _rounds.vals()){
            let exist = _map.get(_round.id);
            switch(exist){
                case(?exist){
                    _map.put(_round.id, _round.deposit + exist);
                };
                case(null){
                    _map.put(_round.id, _round.deposit);
                };
            };
        };

        for((id, amount) in _map.entries()){
            let map : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
                0,
                Text.equal,
                Text.hash,
            );
            map.put("day", #Number(Nat32.toNat(id)));
            map.put("amount", #Number(amount));
            result := Array.append(result,[#Object(map)]);
        };

        let json = #Array(result);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _fetchRoundsByPrincipalResponse(principal:Principal) : Http.Response {
        let _map : HashMap.HashMap<Nat32, Nat> = HashMap.HashMap<Nat32, Nat>(
            0,
            Nat32.equal,
            func (a : Nat32) : Nat32 {a},
        );
        let _rounds = _fetchRoundsByPrincipal(principal);
        var result:[JSON] = [];

        for(_round in _rounds.vals()){
            let exist = _map.get(_round.id);
            switch(exist){
                case(?exist){
                    _map.put(_round.id, _round.deposit + exist);
                };
                case(null){
                    _map.put(_round.id, _round.deposit);
                };
            };
        };

        for((id, amount) in _map.entries()){
            let map : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
                0,
                Text.equal,
                Text.hash,
            );
            map.put("day", #Number(Nat32.toNat(id)));
            map.put("amount", #Number(amount));
            result := Array.append(result,[#Object(map)]);
        };

        let json = #Array(result);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _fetchRoundResponse(round:Nat32) : Http.Response {
        let _rounds =  _fetchRounds();
        var result:[JSON] = [];

        let exist = rounds.get(round);

        switch(exist) {
            case(?exist){
                let _rounds = Iter.toArray(Trie.iter<Principal, Round>(exist));
                for ((id,_round) in _rounds.vals()) {
                    let map : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
                        0,
                        Text.equal,
                        Text.hash,
                    );
                    map.put("owner", #String(Principal.toText(_round.holder)));
                    map.put("amount", #Number(_round.deposit));
                    result := Array.append(result,[#Object(map)]);
                };
            };
            case(null){

            };
        };

        let json = #Array(result);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };
};