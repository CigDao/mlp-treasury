import Constants "../Constants";
import Result "mo:base/Result";

module {

    public type TxReceipt = {
        #Ok: Nat;
        #Err: {
            #InsufficientAllowance;
            #InsufficientBalance;
            #InsufficientPoolBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other: Text;
            #BlockUsed;
            #AmountTooSmall;
            #Slippage:Nat;
        };
    };

    public let canister = actor(Constants.swapCanister) : actor { 
        provide : (Nat, Nat) -> async TxReceipt;
        withdraw : (Nat) -> async TxReceipt;
        getWithdrawEstimate: (Nat) -> async {share1:Nat;share2:Nat};
        swapToken1: (Nat,Nat) -> async TxReceipt;
        getSwapToken1Estimate: (Nat) -> async Nat;
        getSwapToken1EstimateGivenToken2: (Nat) -> async TxReceipt;
        swapToken2: (Nat, Nat) -> async TxReceipt;
        getSwapToken2Estimate: (Nat) -> async Nat;
        getSwapToken2EstimateGivenToken1: (Nat) -> async TxReceipt;
        getEquivalentToken1Estimate: (Nat) -> async Nat;
        getEquivalentToken2Estimate: (Nat) -> async Nat;
    };
}