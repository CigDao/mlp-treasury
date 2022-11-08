import Constants "../Constants";
import Result "mo:base/Result";

module {
    
    public type TxError = {
        #InsufficientAllowance;
        #InsufficientBalance;
        #ErrorOperationStyle;
        #Unauthorized;
        #LedgerTrap;
        #ErrorTo;
        #Other;
        #BlockUsed;
        #FetchRateFailed;
        #NotifyDfxFailed;
        #UnexpectedCyclesResponse;
        #AmountTooSmall;
        #InsufficientXTCFee;
    };

    public type TxReceipt = {
        #Ok:Nat;
        #Err:TxError;
    };

    public type BurnRequest = {
        canister_id:Principal;
        amount:Nat64;
    };

    public type TokenInfoExt = {
        id: Text;
        name: Text;
        symbol: Text;
        decimals: Nat8;
        fee: Nat; // fee for internal transfer/approve
        totalSupply: Nat;
    };

    public type PairInfoExt = {
        id: Text;
        token0: Text; //Principal;
        token1: Text; //Principal;
        creator: Principal;
        reserve0: Nat;
        reserve1: Nat;
        price0CumulativeLast: Nat;
        price1CumulativeLast: Nat;
        kLast: Nat;
        blockTimestampLast: Int;
        totalSupply: Nat;
        lptoken: Text;
    };

    type UserInfo = {
        balances: [(Principal, Nat)]; // user token balances [(token id, balance)...]
        lpBalances: [(Text, Nat)]; // user lp token balances [(lp token id, balance)...]; lp token decimal = 8
    };

    type SwapInfo = {
        owner : Principal; // Sonic canister creator
        cycles : Nat; // Sonic canister cycles balance
        tokens: [TokenInfoExt]; // supported tokens info
        pairs: [PairInfoExt]; // supported pairs info
    };

    public let canister = actor(Constants.Sonic_Canister) : actor { 
        addLiquidity: (Principal, Principal, Nat, Nat, Nat, Nat, Int) -> async TxReceipt;
        removeLiquidity: (Principal, Principal, Nat, Nat, Nat, Int) -> async TxReceipt;
        swapExactTokensForTokens: (Nat,Nat, [Text], Principal, Int) -> async TxReceipt;
        swapTokensForExactTokens: (Nat,Nat, [Text], Principal, Int) -> async TxReceipt;
        getPair: (Principal, Principal) -> async ?PairInfoExt;
        getUserLPBalances: (Principal) -> async [(Text, Nat)]
    };
}