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
import CansiterService "../services/CansiterService";
import TreasuryService "../services/TreasuryService";
import ControllerService "../services/ControllerService";

actor class Dao() = this {

  stable var proposalId:Nat32 = 1;
  stable var voteId:Nat32 = 1;
  stable var totalTokensSpent:Nat = 0;
  private let executionTime:Int = 86400000000000 * 3;
  stable var proposal:?Proposal = null;

  private type ErrorMessage = { #message : Text;};
  private type Proposal = Proposal.Proposal;
  private type ProposalRequest = Proposal.ProposalRequest;
  private type Vote = Vote.Vote;
  private type JSON = JSON.JSON;
  private type ApiError = Response.ApiError;

  private stable var proposalVoteEntries : [(Nat32,[Vote])] = [];
  private var proposalVotes = HashMap.fromIter<Nat32,[Vote]>(proposalVoteEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

  /*private stable var proposalEntries : [(Nat32,Proposal)] = [];
  private var proposals = HashMap.fromIter<Nat32,Proposal>(proposalEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});*/

  private stable var rejectedEntries : [(Nat32,Proposal)] = [];
  private var rejected = HashMap.fromIter<Nat32,Proposal>(rejectedEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

  private stable var acceptedEntries : [(Nat32,Proposal)] = [];
  private var accepted = HashMap.fromIter<Nat32,Proposal>(acceptedEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

  private stable var voteEntries : [(Nat32,Vote)] = [];
  private var votes = HashMap.fromIter<Nat32,Vote>(voteEntries.vals(), 0, Nat32.equal, func (a : Nat32) : Nat32 {a});

  system func preupgrade() {
    proposalVoteEntries := Iter.toArray(proposalVotes.entries());
    voteEntries := Iter.toArray(votes.entries());
    //proposalEntries := Iter.toArray(proposals.entries());
    rejectedEntries := Iter.toArray(rejected.entries());
    acceptedEntries := Iter.toArray(accepted.entries());
  };

  system func postupgrade() {
    proposalVoteEntries := [];
    voteEntries := [];
    //proposalEntries := [];
    rejectedEntries := [];
    acceptedEntries := [];
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

  public shared({caller}) func executeProposal(): async TokenService.TxReceipt {
    let exist = proposal;
    let now = Time.now();
    let controller = Principal.fromText(Constants.controllerCanister);
    if(caller != controller){
     return #Err(#Unauthorized);
    };
    switch(exist){
      case(?exist){
        switch(exist){
          case(#upgrade(value)){
            let timeCheck = value.timeStamp + executionTime;
            if(timeCheck <= now){
              ignore _tally();
            }
          };
          case(#treasury(value)){
            let timeCheck = value.timeStamp + executionTime;
            if(timeCheck <= now){
              ignore _tally();
            }
          }
        }
      };
      case(null){
        return #Err(#Other("No Active Proposals"));
      }
    };
    #Ok(0);
  };

  public shared({caller}) func createProposal(request:ProposalRequest): async TokenService.TxReceipt {
    switch(proposal){
      case(?proposal){
        #Err(#ActiveProposal);
      };
      case(null){
        await _createProposal(caller, request);
      }
    }
  };

  private func _createProposal(caller:Principal, request:ProposalRequest): async TokenService.TxReceipt {
    //verify the amount of tokens is approved
    let allowance = await TokenService.allowance(caller,Principal.fromActor(this));
    if(Constants.proposalCost > allowance){
      return #Err(#InsufficientAllowance);
    };
    //verify hash if upgrading wasm
    switch(request){
      case(#upgrade(obj)){
        let hash = Utils._hash(obj.wasm);
        if(hash != obj.hash){
          return #Err(#Other("Invalid wasm. Wasm hash does not match source"));
        };

        //tax tokens
        let receipt = await TokenService.chargeTax(caller,Constants.proposalCost);
        switch(receipt){
          case(#Ok(value)){
            //create proposal
            let currentId = proposalId;
            proposalId := proposalId+1;
            let upgrade = {
              id = currentId;
              creator = Principal.toText(caller);
              wasm = obj.wasm;
              args = obj.args;
              title = obj.title;
              description = obj.description;
              source = obj.source;
              hash = obj.hash;
              yay = 0;
              nay = 0;
              executed = false;
              executedAt = null;
              timeStamp = Time.now();
            };
            proposal := ?#upgrade(upgrade);
            #Ok(Nat32.toNat(currentId));
          };
          case(#Err(value)){
            #Err(value);
          };
        }
      };
      case(#treasury(obj)){
        let receipt = await TokenService.chargeTax(caller,Constants.proposalCost);
        switch(receipt){
          case(#Ok(value)){
            //create proposal
            let currentId = proposalId;
            proposalId := proposalId+1;
            let treasury = {
              id = currentId;
              treasuryRequestId = obj.treasuryRequestId;
              creator = Principal.toText(caller);
              vote = obj.vote;
              title = obj.title;
              description = obj.description;
              yay = 0;
              nay = 0;
              executed = false;
              executedAt = null;
              timeStamp = Time.now();
            };
            proposal := ?#treasury(treasury);
            #Ok(Nat32.toNat(currentId));
          };
          case(#Err(value)){
            #Err(value);
          };
        }
      }
    };
  };

  public shared({caller}) func vote(proposalId:Nat32, power:Nat, yay:Bool): async TokenService.TxReceipt {
    //verify the amount of tokens is approved
    let allowance = await TokenService.allowance(caller,Principal.fromActor(this));
    if(power > allowance){
      return #Err(#InsufficientAllowance);
    };
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
        _addVoteToProposal(proposalId, vote);
        #Ok(Nat32.toNat(currentId));
      };
      case(#Err(value)){
        #Err(value);
      };
    }
  };

  private func _vote(proposalId:Nat32, power:Nat, yay:Bool) {
    let exist = proposal;
    switch(exist){
      case(?exist){
        switch(exist){
          case(#upgrade(value)){
            if(yay){
              var _proposal = {
                id = value.id;
                creator = value.creator;
                wasm = value.wasm;
                args = value.args;
                title = value.title;
                description = value.description;
                source = value.source;
                hash = value.hash;
                yay = value.yay + power;
                nay = value.nay;
                executed = value.executed;
                executedAt = value.executedAt;
                timeStamp = Time.now();
              };
              proposal := ?#upgrade(_proposal);
            }else {
              var _proposal = {
                id = value.id;
                creator = value.creator;
                wasm = value.wasm;
                args = value.args;
                title = value.title;
                description = value.description;
                source = value.source;
                hash = value.hash;
                yay = value.yay;
                nay = value.nay + power;
                executed = value.executed;
                executedAt = value.executedAt;
                timeStamp = Time.now();
              };
              proposal := ?#upgrade(_proposal);
            }
          };
          case(#treasury(value)){
            if(yay){
              var _proposal = {
                id = value.id;
                treasuryRequestId = value.treasuryRequestId;
                creator = value.creator;
                vote = value.vote;
                title = value.title;
                description = value.description;
                yay = value.yay + power;
                nay = value.nay;
                executed = value.executed;
                executedAt = value.executedAt;
                timeStamp = Time.now();
              };
              proposal := ?#treasury(_proposal);
            }else {
              var _proposal = {
                id = value.id;
                treasuryRequestId = value.treasuryRequestId;
                creator = value.creator;
                vote = value.vote;
                title = value.title;
                description = value.description;
                yay = value.yay;
                nay = value.nay + power;
                executed = value.executed;
                executedAt = value.executedAt;
                timeStamp = Time.now();
              };
              proposal := ?#treasury(_proposal);
            }
          }
        };
      };
      case(null){

      };
    };

  };

  private func _addVoteToProposal(proposalId:Nat32, vote:Vote) {
    let exist = proposalVotes.get(proposalId);
    switch(exist){
      case(?exist){
        let votes = Array.append(exist,[vote]);
        proposalVotes.put(proposalId,votes);
      };
      case(null){
        proposalVotes.put(proposalId,[vote]);
      }
    };
  };

  private func _tally(): async () {
    switch(proposal){
      case(?proposal){
        switch(proposal){
          case(#upgrade(value)){
            if(value.yay > value.nay) {
              //accepted
              accepted.put(value.id,#upgrade(value));
              //make call to controller cansiter that should be blackedholed to upgrade this canister
              ignore ControllerService.upgradeDao(value.wasm,value.args);
            }else {
              rejected.put(value.id,#upgrade(value));
              //rejected
            }
          };
          case(#treasury(value)){
            if(value.yay > value.nay) {
              //accepted
              accepted.put(value.id,#treasury(value));
              //make call to treasury cansiter that should be blackedhole
              ignore TreasuryService.approveRequest(value.treasuryRequestId);
            }else {
              rejected.put(value.id,#treasury(value));
            }
          }
        };
      };
      case(null){

      }
    };
    proposal := null;
  };

  /*private func _transfer(transfer : Transfer): async TokenService.TxReceipt {
    await TokenService.transfer(transfer.recipient,transfer.amount);
  };*/

  public query func http_request(request : Http.Request) : async Http.Response {
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
    };

};