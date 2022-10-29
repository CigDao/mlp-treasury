import Blob "mo:base/Blob";

module {
    public type Proposal = {
        #upgrade:Upgrade;
        #treasury:Treasury;
    };

    public type Upgrade = {
        creator:Text;
        wasm:Blob;
        args:Blob;
        title:Text;
        description:Text;
        source:Text;
        hash:Text;
        yay:Nat;
        nay:Nat;
    };

    public type Treasury = {
        creator:Text;
        vote:Bool;
        title:Text;
        description:Text;
        yay:Nat;
        nay:Nat;
    };
}