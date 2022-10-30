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
import TokenService "../services/TokenService";
import Constants "../Constants";

actor class Treasury() = this{

  stable var requestId:Nat32 = 1;
  stable var threshold:Nat = 1;
  stable var owner = Principal.fromText(Constants.daoCanister);

  private type ErrorMessage = { #message : Text;};
  private type Request = Request.Request;
  private type RequestDraft = Request.RequestDraft;
  private type Transfer = Request.Transfer;
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

  public shared({caller}) func createRequest(request : RequestDraft) : async Nat32 {
    let isMember = _isMember(caller);
    assert(isMember.value);
    var currentId = requestId;
    requestId := requestId + 1;
    let _request = _createRequest(currentId, request, caller, isMember.power);
    requests.put(currentId,_request);
    currentId;
  };

  private func _createRequest(id:Nat32, request : RequestDraft, caller:Principal, power:Nat) : Request {
    let approvals:TrieMap.TrieMap<Text, Nat> = TrieMap.TrieMap<Text,Nat>(Text.equal, Text.hash);
    approvals.put(Principal.toText(caller),power);
    switch(request){
      case(#transfer(value)){
          let result = {
            id = id;
            amount = value.amount;
            recipient = value.recipient;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
            description = value.description;
          };
          #transfer(result);
      };
      case(#addMember(value)){
          let result = {
            id = id;
            principal = value.principal;
            power = value.power;
            description = value.description;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
          };
          #addMember(result);
      };
      case(#removeMember(value)){
          let result = {
            id = id;
            principal = value.principal;
            power = value.power;
            description = value.description;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
          };
          #removeMember(result);
      };
      case(#threshold(value)){
         let result = {
            id = id;
            power = value.power;
            description = value.description;
            approvals = approvals;
            executed = false;
            createdAt = Time.now();
            executedAt = null;
          };
          #threshold(result);
      };
    }
  };

  public shared({caller}) func approveRequest(id : Nat32) : async Result.Result<(), ErrorMessage> {
    let isMember = _isMember(caller);
    assert(isMember.value);
    let request = requests.get(id);
    switch(request){
      case(?request){
        ignore _approveRequest(request,Principal.toText(caller),isMember.power);
        ignore submitRequest(id);
        #ok();
      };
      case(null){
        #err(#message("No Request Found"));
      };
    };
  };

  private func submitRequest(id : Nat32) : async Result.Result<(?TokenService.TxReceipt), ErrorMessage> {
    /*let isMember = _isMember(caller);
    assert(isMember.value);*/
    let request = requests.get(id);
    switch(request){
      case(?request){
        let result = _thresholdCheck(request);
        if(result){
          switch(request){
            case(#transfer(value)){
                let result = await _transfer(value);
                return #ok(?result);
            };
            case(#addMember(value)){
                _addMember(value)
            };
            case(#removeMember(value)){
                _removeMember(value)
            };
            case(#threshold(value)){
                _setThreshold(value);
            };
        };
          #ok(null);
        }else{
          #err(#message("Not enough power"));
        }
      };
      case(null){
        #err(#message("No Request Found"));
      };
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

  private func _transfer(transfer : Transfer): async TokenService.TxReceipt {
    await TokenService.transfer(Principal.fromText(transfer.recipient),transfer.amount);
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
        value.approvals.put(principal,power);
        #transfer(value);
      };
      case(#addMember(value)){
        value.approvals.put(principal,power);
        #addMember(value);
      };
      case(#removeMember(value)){
        value.approvals.put(principal,power);
        #removeMember(value);
      };
      case(#threshold(value)){
        value.approvals.put(principal,power);
        #threshold(value);
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
