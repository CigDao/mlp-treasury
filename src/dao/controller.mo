import Proposal "./models/Proposal";
import CansiterService "../services/CansiterService";
import Constants "../Constants";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import DaoService "../services/DaoService";
import Time "mo:base/Time";
import TopUpService "../services/TopUpService";
import Prim "mo:prim";
import Cycles "mo:base/ExperimentalCycles";

actor class Controller() = this {

    private var min = 60000000000;
    private let day:Int = 86400000000000;
    private var lastCheck = Time.now();
    
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
    
    public func testExecute(): async () {
        ignore _topUp();
        let exist = await DaoService.getProposal();
        let executionTime  = await DaoService.getExecutionTime();
        let now = Time.now();
        await DaoService.executeProposal();
        switch(exist){
            case(?exist){
                switch(exist){
                    case(#upgrade(value)){
                        let timeCheck = value.timeStamp + executionTime;
                        if(timeCheck <= now){
                            if(value.yay > value.nay) {
                                switch(value.canister){
                                    case(#dao){
                                        let canister = Principal.fromText(Constants.daoCanister);
                                        try {
                                            return await _upgrade(canister,value.wasm,value.args);
                                        }
                                        catch e {
                                            throw(e)
                                        }
                                        
                                    };
                                    case(#controller) {
                                        /*let canister = Principal.fromText(Constants.controllerCanister);
                                        try {
                                            return await _upgrade(canister,value.wasm,value.args);
                                        }
                                        catch e {
                                            throw(e)
                                        }*/
                                    };
                                    case(#treasury) {
                                        let canister = Principal.fromText(Constants.treasuryCanister);
                                        try {
                                            return await _upgrade(canister,value.wasm,value.args);
                                        }
                                        catch e {
                                            throw(e)
                                        }
                                    };
                                    case(#community) {
                                        let canister = Principal.fromText(Constants.taxCollectorCanister);
                                        try {
                                            return await _upgrade(canister,value.wasm,value.args);
                                        }
                                        catch e {
                                            throw(e)
                                        }
                                    };
                                };
                            }else {
                                //rejected
                            }
                        };
                    };
                    case(#treasury(value)){};
                    case(#treasuryAction(value)){};
                    case(#tax(value)){};
                    case(#proposalCost(value)){};
                }
            };
            case(null){
    
            }
        };
    };

    private func _upgrade(canister:Principal,wasm:Blob,arg:Blob): async () {
        await CansiterService.CanisterUtils().installCode(canister, arg, wasm);
    };
}