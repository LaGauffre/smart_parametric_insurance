// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract PricingLogic {
    uint256 public constant factor = 10 ** 4; // Numerical precision
    address public owner; // Ethereum address of the owner of the contract
    

    // Define a struct to hold polynomial coefficients
    struct PolyCoeffs {
        int256 c0;
        int256 c1;
        int256 c2;
        int256 c3;
        int256 c4;
    }

    // Mapping from station name to polynomial coefficients
    mapping(string => PolyCoeffs) public stationCoeffs;

    constructor() {
        owner = msg.sender;

        // Initialize coefficients for "MARSEILLE-MARIGNANE"
        stationCoeffs["MARSEILLE-MARIGNANE"] = PolyCoeffs(
           61866466488584768,    // 6.08088853e-02 * 1e11
            1279067435587755,     // 1.30072825e-03 * 1e11
            -22081841812020,      // -2.22982823e-05 * 1e11
            109525424150,         // 1.10635770e-07 * 1e11
            -160548258           // -1.62373694e-10 * 1e11
        );

        // Initialize coefficients for "STRASBOURG-ENTZHEIM"
        stationCoeffs["STRASBOURG-ENTZHEIM"] = PolyCoeffs(
            76579341005774688,     // 7.53896117e-02 * 1e11
            -322886972669433,       // -2.16506423e-04 * 1e11
            13084236350914,        // 1.17177460e-05 * 1e11
            -66687593698,         // -6.10554025e-08 * 1e11
            91781331              // 8.44071936e-11 * 1e11
        );
    }

    // function getQuote(uint256 T, string memory station, uint256 l, uint16 eta) public view returns (uint256) {
    //     uint256 p = getProbability(T, station);
    //     uint256 pp = (l * p) / factor;
    //     uint256 cp = (pp * (factor + eta)) / factor;
    //     return cp;
    // }

    function getProbability(uint256 T, string memory station) public view returns (uint) {
        // Retrieve the coefficients for the given station
        PolyCoeffs memory coeffs = stationCoeffs[station];

        // // Scale T by 1e10 for fixed-point arithmetic
        int256 scaledT = int256(T);
        int result = coeffs.c4; // Start with the highest degree coefficient

        // // Evaluate the polynomial using Horner's method
        result = result * scaledT + coeffs.c3;
        result = result * scaledT + coeffs.c2;
        result = result * scaledT + coeffs.c1;
        result = result * scaledT + coeffs.c0;

        // Return the result scaled down by 1e10
        return uint256(result * int256(factor) / 1e18);
    }
}