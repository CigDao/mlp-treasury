import Proposal "./models/Proposal";
import CansiterService "../services/CansiterService";
import Constants "../Constants";
import Principal "mo:base/Principal";

actor class Controller() = this {

    private type Proposal = Proposal.Proposal;

    var proposal:?Proposal = null;


    system func heartbeat() : async () {
        switch(proposal){
            case(?proposal){
                switch(proposal){
                    case(#upgrade(value)){
                        let daoCansiter = Principal.fromText(Constants.daoCanister);
                        ignore CansiterService.CanisterUtils().installCode(daoCansiter, value.args, value.wasm);
                    };
                    case(#treasury(value)){
                    
                    }
                }
            };
            case(null){

            }
        }
    }
}