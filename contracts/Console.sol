pragma solidity >=0.4.22 <0.9.0;

contract Console {
    event LogUint(string, uint256);

    function log(string memory s, uint256 x) public {
        emit LogUint(s, x);
    }

    function log(string memory s, uint128 x) public {
        emit LogUint(s, x);
    }

    event LogInt(string, int256);

    function log(string memory s, int256 x) public {
        emit LogInt(s, x);
    }

    event LogAddress(string, address);

    function log(string memory s, address x) public {
        emit LogAddress(s, x);
    }

    event LogBool(string, bool);
    function log(string memory s, bool x) public {
        emit LogBool(s, x);
    }

    event LogStr(string);

    function log(string memory s) public {
        emit LogStr(s);
    }
}
