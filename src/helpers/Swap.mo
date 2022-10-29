import Nat "mo:base/Nat";

module {

    public func getAmountOut(amountIn:Nat, reserveIn:Nat, reserveOut:Nat) : Nat {
        assert(amountIn > 0);
        assert(reserveIn > 0);
        assert(reserveOut > 0);

        var amountInWithFee:Nat = Nat.mul(amountIn,997);
        var numerator:Nat = Nat.mul(amountInWithFee,reserveOut);
        var _denominator:Nat = Nat.mul(reserveIn,1000) + amountInWithFee;
        var denominator:Nat = Nat.add(_denominator,amountInWithFee);
        numerator / denominator;
       
    };

    public func getAmountIn(amountOut:Nat, reserveIn:Nat, reserveOut:Nat) : Nat {
        assert(amountOut > 0);
        assert(reserveIn > 0);
        assert(reserveOut > 0);

        var _numerator:Nat = Nat.mul(reserveIn,amountOut);
        var numerator:Nat = Nat.mul(_numerator,1000);
        var _denominator:Nat = Nat.sub(reserveOut,amountOut);
        var denominator:Nat = Nat.mul(_denominator,997);
        numerator / denominator;
       
    }
}