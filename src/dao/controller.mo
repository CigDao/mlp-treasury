import Proposal "./models/Proposal";
import CansiterService "../services/CansiterService";
import Constants "../Constants";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import DaoService "../services/DaoService";
import Time "mo:base/Time";

actor class Controller() = this {

    private var min = 60000000000;
    private let day:Int = 86400000000000;
    private var lastCheck = Time.now();

    /*system func heartbeat() : async () {
        let now = Time.now();
        let timespan = now - lastCheck;
        if(timespan > day){
            lastCheck := now;
            ignore DaoService.executeProposal();
        };
    };*/

    /*system func heartbeat() : async () {
        let now = Time.now();
        let timespan = now - lastCheck;
        if(timespan > min){
            lastCheck := now;
            ignore DaoService.executeProposal();
        };
    };*/
    
    
    public func testExecute(): async () {
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
                                        let canister = Principal.fromText(Constants.communityCanister);
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