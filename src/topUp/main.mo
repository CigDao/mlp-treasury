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
import Http "../helpers/http";
import Utils "../helpers/Utils";
import JSON "../helpers/JSON";
import Response "../models/Response";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Error "mo:base/Error";
import DatabaseService "../services/DatabaseService";
import WXTCService "../services/WXTCService";
import Constants "../Constants";

actor class TopUp() = this{

    private let amount:Nat64 = 20000000000000;
    
    public shared({caller}) func topUp(): async () {
        let canister = Principal.toText(caller);
        let isAuth = await _isAuth(canister);
        assert(isAuth);
        let request = {
            canister_id = caller;
            amount = amount;

        };
        ignore await WXTCService.canister.burn(request);

    };

    private func _isAuth(canister:Text):async Bool {
        var canister_list:[Text] = [];
        canister_list := Array.append(canister_list,[Constants.dip20Canister]);
        canister_list := Array.append(canister_list,[Constants.daoCanister]);
        canister_list := Array.append(canister_list,[Constants.treasuryCanister]);
        canister_list := Array.append(canister_list,[Constants.controllerCanister]);
        canister_list := Array.append(canister_list,[Constants.taxCollectorCanister]);
        canister_list := Array.append(canister_list,[Constants.databaseCanister]);
        canister_list := Array.append(canister_list,[Constants.reflectionDatabaseCanister]);
        canister_list := Array.append(canister_list,[Constants.distributionCanister]);

        let partitions = await _fetchPartitions();
        canister_list := Array.append(canister_list,partitions);

        let exist = Array.find(canister_list,func(e:Text):Bool{e == canister});

        switch(exist){
            case(?exist){
                return true;
            };
            case(null){
                return false;
            };
        };
    };

    private func _fetchPartitions(): async [Text] {
        var results:[Text] = [];
        let transactionDBList = await DatabaseService.getCanistersByPK(Constants.databaseCanister,Constants.databasePK);
        let reflectionDBList = await DatabaseService.getCanistersByPK(Constants.reflectionDatabaseCanister,Constants.reflectionPK);
        results := Array.append(results,transactionDBList);
        results := Array.append(results,reflectionDBList);
        results;
    };

}