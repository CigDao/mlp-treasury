import Prim "mo:prim";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import TrieMap "mo:base/TrieMap";
import List "mo:base/List";
import Time "mo:base/Time";
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
import TokenService "../services/TokenService";
import WICPService "../services/WICPService";
import CommunityService "../services/CommunityService";
import CansiterService "../services/CansiterService";
import TreasuryService "../services/TreasuryService";
import ControllerService "../services/ControllerService";

actor class Distribution(_owner:Principal) = this {

    private let roundTime:Int = 86400000000000;
    private stable var lastRoundEnd:Int = 0;
    private stable var tokensPerRound:Nat = 0;

    private stable var roundId:Nat32 = 0;
    private stable var accountId:Nat32 = 0;
    private stable var lastRound:Nat32 = 0;

    private type ErrorMessage = { #message : Text;};
    private type JSON = JSON.JSON;
    private type ApiError = Response.ApiError;
    private type Round = Round.Round;

    private stable var roundEntries : [(Nat32,[Principal])] = [];
    private var rounds = HashMap.fromIter<Nat32,[Principal]>(roundEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

    private stable var accountEntries : [(Principal,[Round])] = [];
    private var deposits = HashMap.fromIter<Principal,[Round]>(accountEntries.vals(), 0, Principal.equal, Principal.hash);

    system func preupgrade() {
        roundEntries := Iter.toArray(rounds.entries());
        accountEntries := Iter.toArray(deposits.entries());
    };

    system func postupgrade() {
        roundEntries := [];
        accountEntries := [];
    };

    system func heartbeat() : async () {
        let now = Time.now();
        let elapsed = now - lastRoundEnd;
        if(elapsed > roundTime and roundId <= lastRound) {
            lastRoundEnd := now;
            if(roundId < lastRound) {
                roundId := roundId + 1;
            };
            //distribute tokens and update deposits
        };
    };

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

    public shared({caller}) func start(_lastRound:Nat): async () {
        roundId := 1;
        lastRound := Nat32.fromNat(_lastRound);
        let supply = await _tokenSupply();
        tokensPerRound :=  Nat.div(supply,_lastRound);
    };

    public shared({caller}) func claim(round:Nat32): async TokenService.TxReceipt {
        let exist = rounds.get(round);
        switch(exist){
            case(?exist){
                let principal = Array.find<Principal>(exist,func(e:Principal){e == caller});
                switch(principal){
                    case(?principal){
                        let currentRounds = deposits.get(principal);
                        switch(currentRounds){
                            case(?currentRounds){
                                let currentRound = Array.find<Round>(currentRounds,func(e:Round){e.id == round});
                                //check if any rounds match the current one
                                switch(currentRound){
                                    case(?currentRound){
                                        let total = _roundTotal(round);
                                        let payout = roundPayout(total,currentRound.deposit);
                                        //transfer amount 
                                        return await TokenService.transfer(caller,payout);
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

    public shared({caller}) func deposit(amount:Nat): async WICPService.TxReceipt {
        assert(amount > 0);
        let currentId = roundId;
        let spender = Principal.fromActor(this);
        let treasury = Principal.fromText(Constants.treasuryCanister);
        let allowance = await WICPService.canister.allowance(caller,spender);
        if(allowance < amount){
            return #Err(#InsufficientAllowance);
        };
        let result = await WICPService.canister.transferFrom(caller,treasury,amount);

        switch(result){
            case(#Ok(value)){
                let exist = rounds.get(currentId);
                //deposits.put(caller,round);
                switch(exist){
                    //checks if round exist
                    case(?exist) {
                        let principal = Array.find<Principal>(exist,func(e:Principal){e == caller});
                        //check if principal already exist for the round
                        switch(principal){
                            case(?principal){
                                let currentRounds = deposits.get(principal);
                                // checks if the principal has any rounds it participated in
                                switch(currentRounds){
                                    case(?currentRounds){
                                        let currentRound = Array.find<Round>(currentRounds,func(e:Round){e.id == currentId});
                                        //check if any rounds match the current one
                                        switch(currentRound){
                                            case(?currentRound){
                                                let round = {
                                                    id = currentId;
                                                    holder = caller;
                                                    deposit = currentRound.deposit + amount;
                                                    recieved = 0;
                                                };

                                                let _currentRounds = Array.append(currentRounds,[round]);
                                                deposits.put(caller,_currentRounds);
                                            };
                                            case(null){
                                                let round = {
                                                    id = currentId;
                                                    holder = caller;
                                                    deposit = amount;
                                                    recieved = 0;
                                                };
                                                deposits.put(caller,[round]);
                                            };
                                        };
                                    };
                                    case(null){
                                        let round = {
                                            id = currentId;
                                            holder = caller;
                                            deposit = amount;
                                            recieved = 0;
                                        };
                                        deposits.put(caller,[round]);
                                    }
                                };
                            };
                            case(null){
                                let round = {
                                    id = currentId;
                                    holder = caller;
                                    deposit = amount;
                                    recieved = 0;
                                };
                                deposits.put(caller,[round]);
                                rounds.put(currentId,[caller]);
                            };
                        };
                    };
                    case(null){
                        let round = {
                            id = currentId;
                            holder = caller;
                            deposit = amount;
                            recieved = 0;
                        };
                        deposits.put(caller,[round]);
                        rounds.put(currentId,[caller]);
                    };
                };
            };
            case(#Err(value)){
               
            };
        };

        result;
    };

    private func _tokenSupply(): async Nat {
        await TokenService.totalSupply();
    };

    private func _roundTotal(round:Nat32): Nat {
        let exist = rounds.get(round);
        switch(exist){
            case(?exist){
                var amount = 0;
                for (principal in exist.vals()){
                    let _deposits = deposits.get(principal);
                    switch(_deposits){
                        case(?_deposits){
                            for (deposit in _deposits.vals()){
                                if(deposit.id == round){
                                    amount := amount + deposit.deposit;
                                };
                            };
                        };
                        case(null){

                        };
                    };
                };
                amount;
            };
            case(null){
                return 0;
            };
        };
    };

    private func roundPayout(total:Nat,deposit:Nat): Nat {
        let percentage = Nat.div(deposit,total);
        Nat.mul(tokensPerRound,percentage);
    };

    /*public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));

        if (path.size() == 1) {
            switch (path[0]) {
                case ("getProposal") return _proposalResponse();
                case ("fetchAcceptedProposals") return _fetchAcceptedProposalResponse();
                case ("fetchRejectedProposals") return _fetchRejectedProposalResponse();
                case ("getMemorySize") return _natResponse(_getMemorySize());
                case ("getHeapSize") return _natResponse(_getHeapSize());
                case ("getCycles") return _natResponse(_getCycles());
                case (_) return return Http.BAD_REQUEST();
            };
        } else if (path.size() == 2) {
            switch (path[0]) {
                case ("fetchVotes") return _fetchVoteResponse(path[1]);
                case ("getVote") return _voteResponse(path[1]);
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

    private func _fetchAcceptedProposals(): [Proposal] {
        var results:[Proposal] = [];
        for ((id,request) in accepted.entries()) {
        results := Array.append(results,[request]);
        };
        results;
    };

    private func _fetchRejectedProposals(): [Proposal] {
        var results:[Proposal] = [];
        for ((id,request) in rejected.entries()) {
        results := Array.append(results,[request]);
        };
        results;
    };

    private func _fetchVotes(proposalId:Nat32): [Vote] {
        var results:[Vote] = [];
        let exist = proposalVotes.get(proposalId);
        switch(exist){
        case(?exist){
            exist;
        };
        case(null){
            [];
        }
        };
    };

    private func _fetchAcceptedProposalResponse() : Http.Response {
        let _proposals =  _fetchAcceptedProposals();
        var result:[JSON] = [];

        for(proposal in _proposals.vals()) {
        let json = Utils._proposalToJson(proposal);
        result := Array.append(result,[json]);
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

    private func _fetchRejectedProposalResponse() : Http.Response {
        let _proposals =  _fetchRejectedProposals();
        var result:[JSON] = [];

        for(proposal in _proposals.vals()) {
        let json = Utils._proposalToJson(proposal);
        result := Array.append(result,[json]);
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

    private func _fetchVoteResponse(value:Text) : Http.Response {
        let id = Utils.textToNat32(value);
        let _votes =  _fetchVotes(id);
        var result:[JSON] = [];

        for(obj in _votes.vals()) {
        let json = Utils._voteToJson(obj);
        result := Array.append(result,[json]);
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

    private func _proposalResponse() : Http.Response {
        let exist = proposal;
        switch(exist){
        case(?exist){
            let json = Utils._proposalToJson(exist);
            let blob = Text.encodeUtf8(JSON.show(json));
            let response : Http.Response = {
                status_code = 200;
                headers = [("Content-Type", "application/json")];
                body = blob;
                streaming_strategy = null;
            };
        };
        case(null){
            return Http.NOT_FOUND();
        };
        };
    };

    private func _voteResponse(value : Text) : Http.Response {
        let id = Utils.textToNat32(value);
        let exist = votes.get(id);
        switch(exist){
        case(?exist){
            let json = Utils._voteToJson(exist);
            let blob = Text.encodeUtf8(JSON.show(json));
            let response : Http.Response = {
                status_code = 200;
                headers = [("Content-Type", "application/json")];
                body = blob;
                streaming_strategy = null;
            };
        };
        case(null){
            return Http.NOT_FOUND();
        };
        };
    };*/

};