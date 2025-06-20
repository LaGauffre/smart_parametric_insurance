// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract ModelPointsLogic {
    address public owner; // Ethereum address of the owner of the contract
    uint256 public constant factor = 10 ** 4; // Numerical precision
    uint256 public mu = 0;
    uint256 public sn2 = 0;
    uint256 public gamma1_unormalized = 0; // Skewness times std to the power 3 of the liability
    uint256 public Nt = 0 ; // Counter for the number of insurance contracts
    uint256 public Nt_MP = 0; // Counter for the number of model points ever created
    uint256 public Nt_MP_active = 0; // Counter for the number of active model points



    // Define a struct to represent an insurance contract
    struct InsuranceContract {
        string station;
        uint256 T; // day in a year
        uint256 p; // probability
        uint256 l; // compensation
        string status; // status of the contract

    }

    // // Define a struct to represent a model point
    struct ModelPoint {
        string station;
        uint256 T; // day in a year
        uint256 p; // probability
        uint256 l_sum; // Sums of the compensations
        uint256 mean; // mean of the Model Point
        uint256 variance; // variance of the Model Point
        uint256 skew_unormalized; // skewness times std to the power 3 of the Model Point
    }

    // Mapping from uint to an array of InsuranceContract
    mapping(uint256 => InsuranceContract) public insuranceContracts;

    // Mapping from uint to an array of ModelPoint
    mapping(uint256 => ModelPoint) public modelPoints;

    constructor() {
        owner = msg.sender;
        }

    function addInsuranceContract(string memory station, uint256 T, uint256 p, uint256 l) public {
        // Calculate mean, variance, and skewness of the payout
        uint256 mean;
        uint256 variance;
        uint256 skew_unormalized;

        // Increment the contract counter
        Nt++;
        // Add the new insurance contract to the mapping
        insuranceContracts[Nt] = InsuranceContract({
            station: station,
            T: T,
            p: p,
            l: l,
            status: "active"
        });
        // Check if a model point with the same T and station exists
        bool modelPointExists = false;
        for (uint256 i = 1; i <= Nt_MP; i++) {
            if (keccak256(abi.encodePacked(modelPoints[i].station)) == keccak256(abi.encodePacked(station)) && modelPoints[i].T == T) {
                // Update the mean, variance and skewness of the liability
                if (modelPoints[i].l_sum == 0) {
                    Nt_MP_active++;
                }
                mu = mu - modelPoints[i].mean;
                sn2 = sn2 - modelPoints[i].variance;
                gamma1_unormalized = gamma1_unormalized - modelPoints[i].skew_unormalized;
                // Update the mean, variance, and skew of the existing model point
                uint256 l_sum = modelPoints[i].l_sum + l;
                modelPoints[i].l_sum = l_sum;
                mean = (p * l_sum) / factor;
                variance = (p * (factor - p)* l_sum * l_sum) / (factor * factor);
                skew_unormalized = p * l_sum * l_sum * l_sum / factor - 3 * mean * variance - mean * mean * mean;
                modelPoints[i].mean = mean;
                modelPoints[i].variance = variance;
                modelPoints[i].skew_unormalized = skew_unormalized;
                mu = mu + modelPoints[i].mean;
                sn2 = sn2 + modelPoints[i].variance;
                gamma1_unormalized = gamma1_unormalized + modelPoints[i].skew_unormalized;
                modelPointExists = true;
                break;
            }
        }

        // If no model point exists, create a new one
        if (!modelPointExists) {
            Nt_MP++;
            Nt_MP_active++;
            mean = (p * l) / factor;
            variance = (p * (factor - p) * l * l) / (factor * factor);
            skew_unormalized = p * l * l * l / factor - 3 * mean * variance - mean * mean * mean;
            
            modelPoints[Nt_MP] = ModelPoint({
                station: station,
                T: T,
                p: p,
                l_sum: l, 
                mean: mean,
                variance: variance,
                skew_unormalized: skew_unormalized
            
            });
            mu = mu + mean;
            sn2 = sn2 + variance;
            gamma1_unormalized = gamma1_unormalized + skew_unormalized;
        }
    }

    function removeInsuranceContract(uint256 index, string memory newStatus) public {
        // require(msg.sender == owner, "Only the owner can remove contracts");
        require(index > 0 && index <= Nt, "Invalid contract index");
        require(
            keccak256(abi.encodePacked(insuranceContracts[index].status)) == keccak256(abi.encodePacked("active")),
            "Contract is not active"
        );
        require(
            keccak256(abi.encodePacked(newStatus)) == keccak256(abi.encodePacked("cancelled")) ||
            keccak256(abi.encodePacked(newStatus)) == keccak256(abi.encodePacked("closed")),
            "Invalid status"
        );

        // Update the status of the contract
        insuranceContracts[index].status = newStatus;

        // Retrieve the contract details
        string memory station = insuranceContracts[index].station;
        uint256 T = insuranceContracts[index].T;
        uint256 l = insuranceContracts[index].l;

        // Update the corresponding model point
        for (uint256 i = 1; i <= Nt_MP; i++) {
            if (keccak256(abi.encodePacked(modelPoints[i].station)) == keccak256(abi.encodePacked(station)) && modelPoints[i].T == T) {
                mu = mu - modelPoints[i].mean;
                sn2 = sn2 - modelPoints[i].variance;
                gamma1_unormalized = gamma1_unormalized - modelPoints[i].skew_unormalized;

                // Update the model point's l_sum, mean, and variance
                modelPoints[i].l_sum -= l;
                if (modelPoints[i].l_sum == 0) {
                    Nt_MP_active--;
                    modelPoints[i].mean = 0;
                    modelPoints[i].variance = 0;
                    modelPoints[i].skew_unormalized = 0;
                } else {
                    uint256 mean = (modelPoints[i].p * modelPoints[i].l_sum) / factor;
                    uint256 variance = (modelPoints[i].p * (factor - modelPoints[i].p) * modelPoints[i].l_sum * modelPoints[i].l_sum) / (factor * factor);
                    uint256 skew_unormalized = modelPoints[i].p * modelPoints[i].l_sum * modelPoints[i].l_sum * modelPoints[i].l_sum / factor - 3 * mean * variance - mean * mean * mean;
                    modelPoints[i].mean = mean;
                    modelPoints[i].variance = variance;
                    modelPoints[i].skew_unormalized = skew_unormalized;
                    mu = mu + mean;
                    sn2 = sn2 + variance;
                    gamma1_unormalized = gamma1_unormalized + skew_unormalized;
                }
                break;
            }
        }
    }

    function cancelAllActiveContracts() public {
        for (uint256 i = 1; i <= Nt; i++) {
            if (keccak256(bytes(insuranceContracts[i].status)) == keccak256(bytes("active"))) {
                removeInsuranceContract(i, "cancelled");
            }
        }
    }
    





}