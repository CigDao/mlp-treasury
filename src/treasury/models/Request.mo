import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

module {
    
    public type Request = {
        #transfer:Transfer;
        #addMember:Member;
        #removeMember:Member;
        #threshold:Threshold;
    };

    public type Transfer = {
        id:Nat32;
        amount:Nat;
        recipient:Text;
        approvals:TrieMap.TrieMap<Text, Nat>;
        executed:Bool;
        createdAt:Time.Time;
        executedAt:?Time.Time;
        description:Text;
    };
    public type Member = {
        id:Nat32;
        principal:Text;
        power:Nat;
        description:Text;
        approvals:TrieMap.TrieMap<Text, Nat>;
        executed:Bool;
        createdAt:Time.Time;
        executedAt:?Time.Time;
    };
    public type Threshold = {
        id:Nat32;
        power:Nat;
        description:Text;
        approvals:TrieMap.TrieMap<Text, Nat>;
        executed:Bool;
        createdAt:Time.Time;
        executedAt:?Time.Time;
    };

    public type RequestDraft = {
        #transfer:TransferDraft;
        #addMember:MemberDraft;
        #removeMember:MemberDraft;
        #threshold:ThresholdDraft;
    };

    public type TransferDraft = {
        amount:Nat;
        recipient:Text;
        description:Text;
    };
    public type MemberDraft = {
        principal:Text;
        power:Nat;
        description:Text;
    };
    public type ThresholdDraft = {
        power:Nat;
        description:Text;
    };
}