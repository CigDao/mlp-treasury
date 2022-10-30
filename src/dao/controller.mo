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

    system func heartbeat() : async () {
        let now = Time.now();
        let timespan = now - lastCheck;
        if(timespan > min){
            lastCheck := now;
            ignore DaoService.executeProposal();
        };
    };
    
    public shared({caller}) func upgradeDao(wasm:Blob,arg:Blob): async () {
        let canisterId = Principal.fromText(Constants.daoCanister);
        await CansiterService.CanisterUtils().installCode(canisterId, arg, wasm);
    };
}