import Prim "mo:prim";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import TrieMap "mo:base/TrieMap";
import List "mo:base/List";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Request "./models/Request";
import Http "../helpers/http";
import Utils "../helpers/Utils";
import JSON "../helpers/JSON";
import Response "../models/Response";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Error "mo:base/Error";
import WICPService "../services/WICPService";
import TokenService "../services/TokenService";
import Constants "../Constants";
import TopUpService "../services/TopUpService";
import SwapService "../services/SwapService";

actor class Treasury() = this{

  stable var requestId:Nat32 = 1;
  stable var threshold:Nat = 1;
  stable var owner = Principal.fromText(Constants.daoCanister);

  private type ErrorMessage = { #message : Text;};
  private type Request = Request.Request;
  private type RequestResponse = Request.RequestResponse;
  private type RequestDraft = Request.RequestDraft;
  private type Transfer = Request.Transfer;
  private type WithdrawLiquidity = Request.WithdrawLiquidity;
  private type Member = Request.Member;
  private type Threshold = Request.Threshold;
  private type JSON = JSON.JSON;
  private type ApiError = Response.ApiError;

  private var requests = HashMap.HashMap<Nat32,Request>( 0, Nat32.equal, func (a : Nat32) : Nat32 {a});
  private stable var memberEntries : [(Principal,Nat)] = [];
  private var members = HashMap.fromIter<Principal,Nat>(memberEntries.vals(), 0, Principal.equal, Principal.hash);
  members.put(owner,1);
  system func preupgrade() {
    memberEntries := Iter.toArray(members.entries());
  };

  system func postupgrade() {
    memberEntries := [];
  };

  public query func fetchMembers(): async [(Principal,Nat)] {
      Iter.toArray(members.entries());
  };

  public query func getThreshold(): async Nat {
      threshold
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

  private func _topUp(): async () {
      if (_getCycles() <= Constants.cyclesThreshold){
          await TopUpService.topUp();
      }
  };

  public shared({caller}) func createRequest(proposalId:Nat32,request : RequestDraft) : async Nat32 {
    ignore _topUp();
    let isMember = _isMember(caller);
    assert(isMember.value);
    var currentId = requestId;
    requestId := requestId + 1;
    let _request = _createRequest(proposalId,currentId, request, caller, isMember.power);
    requests.put(currentId,_request);
    currentId;
  };

  public query func fetchRequests(): async [RequestResponse] {
    var results:[RequestResponse] = [];
    for ((request) in _fetchRequests().vals()) {
      let _request = _removeApprovalsFromRequest(request);
      results := Array.append(results,[_request]);
    };
    results;
  };

  private func _createRequest(proposalId:Nat32,id:Nat32, request : RequestDraft, caller:Principal, power:Nat) : Request {
    let approvals:TrieMap.TrieMap<Text, Nat> = TrieMap.TrieMap<Text,Nat>(Text.equal, Text.hash);
    approvals.put(Principal.toText(caller),power);
    switch(request){
      case(#transfer(value)){
          let result = {
            id = id;
            proposalId = proposalId;
            token = value.token;
            amount = value.amount;
            recipient = value.recipient;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            description = value.description;
            error = null;
          };
          #transfer(result);
      };
      case(#addMember(value)){
          let result = {
            id = id;
            proposalId = proposalId;
            principal = value.principal;
            power = value.power;
            description = value.description;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            error = null;
          };
          #addMember(result);
      };
      case(#removeMember(value)){
          let result = {
            id = id;
            proposalId = proposalId;
            principal = value.principal;
            power = value.power;
            description = value.description;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            error = null;
          };
          #removeMember(result);
      };
      case(#threshold(value)){
         let result = {
            id = id;
            proposalId = proposalId;
            power = value.power;
            description = value.description;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            error = null;
          };
          #threshold(result);
      };
      case(#swapFor(value)){
         let result = {
            id = id;
            proposalId = proposalId;
            token = value.token;
            amount = value.amount;
            recipient = value.recipient;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            description = value.description;
            error = null;
          };
          #swapFor(result);
      };
      case(#withdrawLiquidity(value)){
         let result = {
            id = id;
            proposalId = proposalId;
            amount = value.amount;
            recipient = value.recipient;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            description = value.description;
            error = null;
          };
          #withdrawLiquidity(result);
      };
      case(#addLiquidity(value)){
         let result = {
            id = id;
            proposalId = proposalId;
            token = value.token;
            amount = value.amount;
            recipient = value.recipient;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            description = value.description;
            error = null;
          };
          #addLiquidity(result);
      };
    }
  };

  public shared({caller}) func approveRequest(id : Nat32) : async Result.Result<(), ErrorMessage> {
    ignore _topUp();
    let isMember = _isMember(caller);
    assert(isMember.value);
    let request = requests.get(id);
    switch(request){
      case(?request){
        ignore _approveRequest(request,Principal.toText(caller),isMember.power);
        ignore _submitRequest(id);
        #ok();
      };
      case(null){
        #err(#message("No Request Found"));
      };
    };
  };

  private func _submitRequest(id : Nat32) : async Result.Result<(), ErrorMessage> {
    let request = requests.get(id);
    switch(request){
      case(?request){
        let result = _thresholdCheck(request);
        if(result){
          switch(request){
            case(#transfer(value)){
                assert(value.executed == false);
                let result = await _transfer(value);
                switch(result){
                  case(#ok(value)){
                    let _request = Utils.updateRequest(request,true,null);
                    requests.put(id,_request);
                    return #ok()
                  };
                  case(#err(value)){
                    let _request = Utils.updateRequest(request,true,?value);
                    requests.put(id,_request);
                    return #err(#message(value));
                  }
                };
                return #ok();
            };
            case(#addMember(value)){
                assert(value.executed == false);
                _addMember(value);
                let _request = Utils.updateRequest(request,true,null);
                requests.put(id,_request);
                return #ok()
            };
            case(#removeMember(value)){
                assert(value.executed == false);
                _removeMember(value);
                let _request = Utils.updateRequest(request,true,null);
                requests.put(id,_request);
                return #ok()
            };
            case(#threshold(value)){
                assert(value.executed == false);
                _setThreshold(value);
                let _request = Utils.updateRequest(request,true,null);
                requests.put(id,_request);
                return #ok()
            };
            case(#swapFor(value)){
                assert(value.executed == false);
                let result = await _swapFor(value);
                switch(result){
                  case(#Ok(value)){
                    let _request = Utils.updateRequest(request,true,null);
                    requests.put(id,_request);
                    return #ok()
                  };
                  case(#Err(value)){
                    let err = Utils.swapTxReceiptToText(result);
                    let _request = Utils.updateRequest(request,true,?err);
                    requests.put(id,_request);
                    return #err(#message(err));
                  }
                };
            };
            case(#withdrawLiquidity(value)){
                assert(value.executed == false);
                let result = await _withdrawLiquidity(value);
                switch(result){
                  case(#Ok(value)){
                    let _request = Utils.updateRequest(request,true,null);
                    requests.put(id,_request);
                    return #ok()
                  };
                  case(#Err(value)){
                    let err = Utils.swapTxReceiptToText(result);
                    let _request = Utils.updateRequest(request,true,?err);
                    requests.put(id,_request);
                    return #err(#message(err));
                  }
                };
            };
            case(#addLiquidity(value)){
                assert(value.executed == false);
                let result = await _addLiquidity(value);
                switch(result){
                  case(#Ok(value)){
                    let _request = Utils.updateRequest(request,true,null);
                    requests.put(id,_request);
                    return #ok()
                  };
                  case(#Err(value)){
                    let err = Utils.swapTxReceiptToText(result);
                    let _request = Utils.updateRequest(request,true,?err);
                    requests.put(id,_request);
                    return #err(#message(err));
                  }
                };
            };
          };
          #ok();
        }else{
          #err(#message("Not enough power"));
        }
      };
      case(null){
        #err(#message("No Request Found"));
      };
    };
  };

  private func _swapFor(value : Transfer): async SwapService.TxReceipt {
    let swapCanister = Principal.fromText(Constants.swapCanister);
    switch(value.token){
      case(#yc){
        let estimate = await SwapService.canister.getSwapToken2EstimateGivenToken1(value.amount);
        switch(estimate){
          case(#Ok(amount)){
            let slippage = Utils.floatToNat(Utils.natToFloat(value.amount) - (Utils.natToFloat(value.amount) * 0.01));
            let approve = await WICPService.canister.approve(swapCanister,amount);
            let swap = await SwapService.canister.swapToken2(amount,slippage)
          };
          case(#Err(value)){
            #Err(value)
          }
        };
      };
      case(#icp){
        let estimate = await SwapService.canister.getSwapToken1EstimateGivenToken2(value.amount);
        switch(estimate){
          case(#Ok(amount)){
            let slippage = Utils.floatToNat(Utils.natToFloat(value.amount) - (Utils.natToFloat(value.amount) * 0.01));
            let approve = await TokenService.approve(swapCanister,amount);
            let swap = await SwapService.canister.swapToken1(amount,slippage);
          };
          case(#Err(value)){
            #Err(value)
          }
        };
      }
    };
  };

  private func _withdrawLiquidity(value : WithdrawLiquidity): async SwapService.TxReceipt {
    await SwapService.canister.withdraw(value.amount);
  };

  private func _addLiquidity(value : Transfer): async SwapService.TxReceipt {
   let swapCanister = Principal.fromText(Constants.swapCanister);
   switch(value.token){
      case(#yc){
        let estimate = await SwapService.canister.getEquivalentToken2Estimate(value.amount);
        let approveYC = await TokenService.approve(swapCanister,value.amount);
        switch(approveYC){
          case(#Ok(_)){
            let approveWICP = await WICPService.canister.approve(swapCanister,estimate);
            switch(approveWICP){
              case(#Ok(_)){
                await SwapService.canister.provide(value.amount,estimate);
              };
              case(#Err(value)){
                #Err(#InsufficientAllowance);
              };
            };
          };
          case(#Err(value)){
            #Err(#InsufficientAllowance);
          };
        };
      };
      case(#icp){
        let estimate = await SwapService.canister.getEquivalentToken1Estimate(value.amount);
        let approveYC = await TokenService.approve(swapCanister,estimate);
        switch(approveYC){
          case(#Ok(_)){
            let approveWICP = await WICPService.canister.approve(swapCanister,value.amount);
            switch(approveWICP){
              case(#Ok(_)){
                await SwapService.canister.provide(estimate,value.amount);
              };
              case(#Err(value)){
                #Err(#InsufficientAllowance);
              };
            };
          };
          case(#Err(value)){
            #Err(#InsufficientAllowance);
          };
        };
      }
    };
  };

  private func _addMember(member : Member) {
    let _member = Principal.fromText(member.principal);
    members.put(_member,member.power);
  };

  private func _removeMember(member : Member) {
    let totalPower:Nat = _getTotalPower() - member.power;
    assert(totalPower >= threshold);
    let _member = Principal.fromText(member.principal);
     members.delete(_member);
  };

  private func _setThreshold(_threshold : Threshold) {
    let totalPower:Nat = _getTotalPower();
    assert(totalPower >= _threshold.power);
    threshold := _threshold.power;
  };

  private func _transfer(transfer : Transfer): async Result.Result<(),Text> {
    switch(transfer.token){
      case(#yc){
        let result = await TokenService.transfer(Principal.fromText(transfer.recipient),transfer.amount);
        switch(result){
          case(#Ok(value)){
            #ok();
          };
          case(#Err(value)){
            let err = Utils.ycTxReceiptToText(result);
            #err(err);
          };
        }
      };
      case(#icp){
        let result = await WICPService.canister.transfer(Principal.fromText(transfer.recipient),transfer.amount);
        switch(result){
          case(#Ok(value)){
            #ok();
          };
          case(#Err(value)){
            let err = Utils.wicpTxReceiptToText(result);
            #err(err);
          };
        }
      }
    };
  };

  private func _getTotalPower():Nat {
    var power:Nat = 0;
    for((principal,_power) in members.entries()){
      power := power + _power;
    };
    power;
  };

  private func _approveRequest(request:Request,principal:Text,power:Nat): Request{
    switch(request ){
      case(#transfer(value)){
        assert(value.executed == false);
        value.approvals.put(principal,power);
        #transfer(value);
      };
      case(#addMember(value)){
        assert(value.executed == false);
        value.approvals.put(principal,power);
        #addMember(value);
      };
      case(#removeMember(value)){
        assert(value.executed == false);
        value.approvals.put(principal,power);
        #removeMember(value);
      };
      case(#threshold(value)){
        assert(value.executed == false);
        value.approvals.put(principal,power);
        #threshold(value);
      };
      case(#swapFor(value)){
        assert(value.executed == false);
        value.approvals.put(principal,power);
        #swapFor(value);
      };
      case(#withdrawLiquidity(value)){
        assert(value.executed == false);
        value.approvals.put(principal,power);
        #withdrawLiquidity(value);
      };
      case(#addLiquidity(value)){
        assert(value.executed == false);
        value.approvals.put(principal,power);
        #addLiquidity(value);
      };
    };
  };

  private func _thresholdCheck(request:Request): Bool{
    var _power = 0;
    switch(request ){
      case(#transfer(value)){
        for((member, power) in value.approvals.entries()){
          _power := _power + power;
        };
      };
      case(#addMember(value)){
        for((member, power) in value.approvals.entries()){
          _power := _power + power;
        };
      };
      case(#removeMember(value)){
        for((member, power) in value.approvals.entries()){
          _power := _power + power;
        };
      };
      case(#threshold(value)){
        for((member, power) in value.approvals.entries()){
          _power := _power + power;
        };
      };
      case(#swapFor(value)){
        for((member, power) in value.approvals.entries()){
          _power := _power + power;
        };
      };
      case(#withdrawLiquidity(value)){
        for((member, power) in value.approvals.entries()){
          _power := _power + power;
        };
      };
      case(#addLiquidity(value)){
        for((member, power) in value.approvals.entries()){
          _power := _power + power;
        };
      };
    };
    if(_power >= threshold) {
      return true;
    }else {
      return false;
    }
  };

  private func _isMember(caller:Principal): {value:Bool; power:Nat} {
    let exist = members.get(caller);
    switch(exist){
      case(?exist){
        {
          value = true;
          power = exist;
        }
      };
      case(null){
        {
          value = false;
          power = 0;
        }
      };
    };
  };

  public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() == 1) {
            switch (path[0]) {
                case ("fetchRequests") return _fetchRequestsResponse();
                case ("getMemorySize") return _natResponse(_getMemorySize());
                case ("getHeapSize") return _natResponse(_getHeapSize());
                case ("getCycles") return _natResponse(_getCycles());
                case (_) return return Http.BAD_REQUEST();
            };
        } else if (path.size() == 2) {
            switch (path[0]) {
                case ("getRequest") return _requestResponse(path[1]);
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

    private func _fetchRequests(): [Request] {
      var results:[Request] = [];
      for ((id,request) in requests.entries()) {
        results := Array.append(results,[request]);
      };
      results;
    };

    private func _removeApprovalsFromRequest(request:Request): RequestResponse {
      switch(request){
        case(#swapFor(value)){
          let result = {
            id = value.id;
            proposalId = value.proposalId;
            token = value.token;
            amount = value.amount;
            recipient = value.recipient;
            approvals = value.approvals;
            executed = value.executed;
            createdAt = value.createdAt;
            executedAt = value.executedAt;
            description = value.description;
            error = value.error;
          };
          #swapFor(result)
        };
        case(#withdrawLiquidity(value)){
          let result = {
            id = value.id;
            proposalId = value.proposalId;
            amount = value.amount;
            executed = value.executed;
            createdAt = value.createdAt;
            executedAt = value.executedAt;
            description = value.description;
            error = value.error;
          };
          #withdrawLiquidity(result)
        };
        case(#addLiquidity(value)){
          let result = {
            id = value.id;
            proposalId = value.proposalId;
            token = value.token;
            amount = value.amount;
            recipient = value.recipient;
            approvals = value.approvals;
            executed = value.executed;
            createdAt = value.createdAt;
            executedAt = value.executedAt;
            description = value.description;
            error = value.error;
          };
          #addLiquidity(result)
        };
        case(#transfer(value)){
          let result = {
            id = value.id;
            proposalId = value.proposalId;
            token = value.token;
            amount = value.amount;
            recipient = value.recipient;
            approvals = value.approvals;
            executed = value.executed;
            createdAt = value.createdAt;
            executedAt = value.executedAt;
            description = value.description;
            error = value.error;
          };
          #transfer(result)
        };
        case(#addMember(value)){
          let result = {
            id = value.id;
            proposalId = value.proposalId;
            principal = value.principal;
            power = value.power;
            description = value.description;
            executed = value.executed;
            createdAt = value.createdAt;
            executedAt = value.executedAt;
            error = value.error;
          };
          #addMember(result)
        };
        case(#removeMember(value)){
          let result = {
            id = value.id;
            proposalId = value.proposalId;
            principal = value.principal;
            power = value.power;
            description = value.description;
            executed = value.executed;
            createdAt = value.createdAt;
            executedAt = value.executedAt;
            error = value.error;
          };
          #removeMember(result)
        };
        case(#threshold(value)){
          let result = {
            id = value.id;
            proposalId = value.proposalId;
            power = value.power;
            description = value.description;
            executed = value.executed;
            createdAt = value.createdAt;
            executedAt = value.executedAt;
            error = value.error;
          };
          #threshold(result)
        };
      };
    };

    private func _fetchRequestsResponse() : Http.Response {
      let requests =  _fetchRequests();
      var result:[JSON] = [];

      for(request in requests.vals()) {
        let json = Utils.requestToJson(request);
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

    private func _requestResponse(value : Text) : Http.Response {
      let id = Utils.textToNat32(value);
      let exist = requests.get(id);
      switch(exist){
        case(?exist){
          let json = Utils.requestToJson(exist);
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

};
