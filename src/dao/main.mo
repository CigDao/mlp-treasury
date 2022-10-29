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
import Vote "./models/Vote";
import Proposal "./models/Proposal";
import Http "../helpers/http";
import Utils "../helpers/Utils";
import JSON "../helpers/JSON";
import Constants "../Constants";
import Response "../models/Response";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Error "mo:base/Error";
import TokenService "../services/TokenService";

actor class Dao() = this {

  stable var proposalId:Nat32 = 1;
  stable var voteId:Nat32 = 1;
  stable var totalTokensSpent:Nat = 0;

  private type ErrorMessage = { #message : Text;};
  private type Proposal = Proposal.Proposal;
  private type Vote = Vote.Vote;
  private type JSON = JSON.JSON;
  private type ApiError = Response.ApiError;

  private stable var proposalEntries : [(Nat32,Proposal)] = [];
  private var proposals = HashMap.fromIter<Nat32,Proposal>(proposalEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});
  private stable var voteEntries : [(Nat32,Vote)] = [];
  private var votes = HashMap.fromIter<Nat32,Vote>(voteEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

  system func preupgrade() {
    voteEntries := Iter.toArray(votes.entries());
    proposalEntries := Iter.toArray(proposals.entries());
  };

  system func postupgrade() {
    voteEntries := [];
    proposalEntries := [];
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

  public shared({caller}) func createProposal(proposal:Proposal): async TokenService.TxReceipt {
    //verify the amount of tokens is approved
    let allowance = await TokenService.allowance(caller,Principal.fromActor(this));
    assert(Constants.proposalCost <= allowance);
    //verify hash if upgrading wasm
    switch(proposal){
      case(#upgrade(value)){
        let hash = Utils._hash(value.wasm);
        if(hash != value.hash){
          return #Err(#Other("Invalid wasm. Wasm hash does not match source"));
        };
      };
      case(#treasury(value)){

      }
    };
    //tax tokens
    let receipt = await TokenService.chargeTax(caller,Constants.proposalCost);
    switch(receipt){
      case(#Ok(value)){
        //create proposal
        let currentId = proposalId;
        proposalId := proposalId+1;
        proposals.put(currentId,proposal);
        #Ok(Nat32.toNat(currentId));
      };
      case(#Err(value)){
        #Err(value);
      };
    }
  };

  public shared({caller}) func vote(proposalId:Nat32, power:Nat, yay:Bool): async TokenService.TxReceipt {
    //verify the amount of tokens is approved
    let allowance = await TokenService.allowance(caller,Principal.fromActor(this));
    assert(power <= allowance);
    //tax tokens
    let receipt = await TokenService.chargeTax(caller,Constants.proposalCost);
    switch(receipt){
      case(#Ok(value)){
        let vote = {
          proposalId = proposalId;
          yay = yay;
          member = Principal.toText(caller);
          power = power;
          timeStamp = Time.now();
        };
        //credit vote
        let currentId = voteId;
        voteId := voteId+1;
        votes.put(voteId,vote);
        _vote(proposalId, power, yay);
        #Ok(Nat32.toNat(currentId));
      };
      case(#Err(value)){
        #Err(value);
      };
    }
  };

  private func _vote(proposalId:Nat32, power:Nat, yay:Bool) {
    let exist = proposals.get(proposalId);
    switch(exist){
      case(?exist){
        switch(exist){
          case(#upgrade(value)){
            if(yay){
              var proposal = {
                creator = value.creator;
                wasm = value.wasm;
                args = value.args;
                title = value.title;
                description = value.description;
                source = value.source;
                hash = value.hash;
                yay = value.yay + power;
                nay = value.nay;
              };
              proposals.put(proposalId,#upgrade(proposal));
            }else {
              var proposal = {
                creator = value.creator;
                wasm = value.wasm;
                args = value.args;
                title = value.title;
                description = value.description;
                source = value.source;
                hash = value.hash;
                yay = value.yay;
                nay = value.nay + power;
              };
              proposals.put(proposalId,#upgrade(proposal));
            }
          };
          case(#treasury(value)){
            if(yay){
              var proposal = {
                creator = value.creator;
                vote = value.vote;
                title = value.title;
                description = value.description;
                yay = value.yay + power;
                nay = value.nay;
              };
              proposals.put(proposalId,#treasury(proposal));
            }else {
              var proposal = {
                creator = value.creator;
                vote = value.vote;
                title = value.title;
                description = value.description;
                yay = value.yay;
                nay = value.nay + power;
              };
              proposals.put(proposalId,#treasury(proposal));
            }
          }
        };
      };
      case(null){

      };
    };

  };

  /*private func _transfer(transfer : Transfer): async TokenService.TxReceipt {
    await TokenService.transfer(transfer.recipient,transfer.amount);
  };*/

  public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));

        if (path.size() == 1) {
            let value = path[1];
            switch (path[0]) {
                //case ("fetchRequests") return _fetchRequestsResponse();
                case ("getMemorySize") return _natResponse(_getMemorySize());
                case ("getHeapSize") return _natResponse(_getHeapSize());
                case ("getCycles") return _natResponse(_getCycles());
                case (_) return return Http.BAD_REQUEST();
            };
        } else if (path.size() == 2) {
            switch (path[0]) {
                //case ("getRequest") return _requestResponse(path[1]);
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

    /*private func _fetchRequests(): [Request] {
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
    };*/

};