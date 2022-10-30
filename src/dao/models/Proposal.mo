import Blob "mo:base/Blob";
import Time "mo:base/Time";

module {
    public type Proposal = {
        #upgrade:Upgrade;
        #treasury:Treasury;
    };

    public type ProposalRequest = {
        #upgrade:UpgradeRequest;
        #treasury:TreasuryRequest;
    };

    public type Upgrade = {
        id:Nat32;
        creator:Text;
        wasm:Blob;
        args:Blob;
        title:Text;
        description:Text;
        source:Text;
        hash:Text;
        yay:Nat;
        nay:Nat;
        executed:Bool;
        executedAt:?Time.Time;
        timeStamp:Time.Time;
    };
    public type UpgradeRequest = {
        wasm:Blob;
        args:Blob;
        title:Text;
        description:Text;
        source:Text;
        hash:Text;
    };

    public type TreasuryRequest = {
        vote:Bool;
        title:Text;
        description:Text;
        treasuryRequestId:Nat32;
    };
    public type Treasury = {
        id:Nat32;
        treasuryRequestId:Nat32;
        creator:Text;
        vote:Bool;
        title:Text;
        description:Text;
        yay:Nat;
        nay:Nat;
        executed:Bool;
        executedAt:?Time.Time;
        timeStamp:Time.Time;
    };
}