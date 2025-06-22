// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPricingLogic {
    function getProbability(uint256 T, string memory station) external view returns (uint);
}
interface IModelPointsLogic {
    function sn2() external view returns (uint256);
    function gamma1_unormalized() external view returns (uint256);
    function Nt_MP_active() external view returns (uint256);
    function addInsuranceContract(string memory station, uint256 T, uint256 p, uint256 l) external;
    function removeInsuranceContract(uint256 index, string memory newStatus) external;
    function cancelAllActiveContracts() external;
}

contract InsuranceLogic{
    address public owner; // Ethereum address of the owner of the contract
    uint256 public constant factor = 10 ** 4; // Numerical precision
    uint256 public totalSupply; // Total supply of tokens
    uint256 public rt = 10000; // Exchange rate of token against ETH
    uint256 public Xt; // Reserve to calculate the exchange rate
    uint16 public eta = 1000; // 10% loading (1000 basis points) to reward the token holders
    uint16 public qAlphaSCR = 25758; // standard normal quantile of order alpha = 0.995
    uint16 public qAlphaMCR = 10364; // standard normal quantile of order alpha = 0.995
    uint256 public Nt; // Counter for the number of insurance contracts
    uint256 public Nt_MP_active; // Solvency Capital Requirement
    uint256 public SCR; // Solvency Capital Requirement
    uint256 public MCR; // Minimum Capital Requirement
    uint256 public mu = 0; // mean of the liability distribution
    uint256 public sn = 0; // std of the liability distribution
    uint256 public gamma1 = 0; // Skewness of the liability distribution
    uint256 public l_tot = 0; // Sum of all the potential payouts
    uint256 public Nt_MP_active_min = 5; // Minimum number of model points to trigger SCR and MCR

    struct InsuranceContract {
        address customer; // Address of the policyholder
        uint256 T; // Day of the year between 1 and 365
        bytes32 station; // Description of the insured event
        uint256 l; // Payout amount
        uint256 p; // Probability of the event
        uint16 eta; // loading of the premium at the underwritting time
        uint256 refund; // Refund amount in case of bankruptcy
        uint8 status; // Status of the contract 0 = open, 1 = closed and settled, 2 = closed without compensation, 3 = refunded
    }

    address[] public investorAddresses; // Array to store investor addresses

    mapping(uint256 => InsuranceContract) public insuranceContracts; // Mapping of insurance contracts
    mapping(address => uint256) public Yt; // Balance of investors in tokens
    
    event Fund(address indexed from, uint256 x, uint256 y);
    event Burn(address indexed from, uint256 x, uint256 y);
    event ParametersUpdated(uint16 newEta, uint16 newQAlphaSCR, uint16 newQAlphaMCR, uint256 newSCR, uint256 newMCR);
    event InsuranceUnderwritten(uint256 indexed contractId, address indexed customer, uint256 T, bytes32 station, uint256 l, uint256 cp, uint8 status, uint256 newSCR, uint256 newMCR); 
    event ClaimSettled(uint256 indexed contractId, address indexed customer, bool payoutTransferred, uint256 newSCR, uint256 newMCR);


    IPricingLogic public pricingLogic;
    IModelPointsLogic public modelPointsLogic;

    constructor(address _pricingLogicAddress, address _modelPointsLogicAddress) {
        owner = msg.sender;
        pricingLogic = IPricingLogic(_pricingLogicAddress);
        modelPointsLogic = IModelPointsLogic(_modelPointsLogicAddress);
    }
    receive() external payable {}

    function updateParameters(uint16 newEta, uint16 newQAlphaSCR, uint16 newQAlphaMCR) public {
    require(msg.sender == owner, "Only the owner can update parameters");
    eta = newEta;
    qAlphaSCR = newQAlphaSCR;
    qAlphaMCR = newQAlphaMCR;
    if (Nt_MP_active >= Nt_MP_active_min) {

        SCR = sn * qAlphaSCR / factor + sn * gamma1 * qAlphaSCR * qAlphaSCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
        MCR = sn * qAlphaMCR / factor + sn * gamma1 * qAlphaMCR * qAlphaMCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
    }
    if (Xt < MCR) {
            refundPremiumToPolicyholders();
            if (Xt > 0){
                redistributeToInvestors();
            }
            SCR=0;
            MCR=0;
            sn=0;
            mu=0;
            gamma1=0;
            rt=10000;
            Xt=0;
            Nt_MP_active=0;
            modelPointsLogic.cancelAllActiveContracts();
        }

    emit ParametersUpdated(newEta, newQAlphaSCR, newQAlphaMCR, SCR, MCR);
    }
    
    function fundContract() public payable {
        require(msg.value > 0, "Funding amount must be greater than 0");
        uint256 tokensToMint = (msg.value * (factor)) / rt;
        totalSupply += tokensToMint;
        Xt += msg.value;
        if (Yt[msg.sender] == 0) {
            investorAddresses.push(msg.sender);
            }
        Yt[msg.sender] += tokensToMint;
        emit Fund(msg.sender, msg.value, tokensToMint);
    }

    function withdraw(uint256 _value) public returns (bool success) {
        require(Yt[msg.sender] >= _value, "Insufficient balance");
        uint256 etherAmount = _value * rt / (factor);
        require(Xt - SCR >= etherAmount, "Insufficient contract balance");

        Yt[msg.sender] -= _value;
        totalSupply -= _value;
        Xt -= etherAmount;
        payable(msg.sender).transfer(etherAmount);

        emit Burn(msg.sender, etherAmount, _value);
        
        return true;
    }

    function getQuote(uint256 T, string memory station, uint256 l) public view returns (uint256) {
        uint256 p = pricingLogic.getProbability(T, station);
        uint256 pp = (l * p) / factor;
        uint256 cp = (pp * (factor + eta)) / factor;
        return cp;
    }

    function underwritePolicy(uint256 T, string memory station,  uint256 l) public payable {
        uint256 p = pricingLogic.getProbability(T, station);
        uint256 pp = (l * p) / factor;
        uint256 cp = (pp * (factor + eta)) / factor;
        require(msg.value == cp, "Incorrect premium amount sent");
        Nt++;
        (bool success, ) = payable(address(this)).call{value: msg.value}("");
        require(success, "Failed to transfer premium to reserve");
        modelPointsLogic.addInsuranceContract(station, T, p, l);
        mu += p * l * eta / factor / factor;
        l_tot += l;
        
        Nt_MP_active = modelPointsLogic.Nt_MP_active();
        if (Nt_MP_active < Nt_MP_active_min) {
            SCR = l_tot;
            MCR = l_tot;
        }
        else {
            uint256 sn2 = modelPointsLogic.sn2();
            sn = sqrt(sn2);
            uint256 gamma1_unormalized = modelPointsLogic.gamma1_unormalized();
            gamma1 = gamma1_unormalized / sn / sn / sn;
            
            SCR = sn * qAlphaSCR / factor + sn * gamma1 * qAlphaSCR * qAlphaSCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
            MCR = sn * qAlphaMCR / factor + sn * gamma1 * qAlphaMCR * qAlphaMCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
        }
        uint8 status = 0;
        InsuranceContract memory policy = InsuranceContract({
            customer: msg.sender,
            T: T, 
            station: stringToBytes32(station), // Description of the insured event
            l: l,
            p:p ,
            eta: eta,
            refund:cp,
            status: status});
        if (Xt <= SCR) {
            status = 3;
            policy.status = status;
            modelPointsLogic.removeInsuranceContract(Nt, "cancelled");
            sendPayout(payable(msg.sender), cp);
            mu -= p * l * eta / factor / factor;
            l_tot -= l;
            Nt_MP_active = modelPointsLogic.Nt_MP_active();
            if (Nt_MP_active < Nt_MP_active_min) {
                SCR = l_tot;
                MCR = l_tot;
            }
            else {
                uint256 sn2 = modelPointsLogic.sn2();
                sn = sqrt(sn2);
                uint256 gamma1_unormalized = modelPointsLogic.gamma1_unormalized();
                gamma1 = gamma1_unormalized / sn / sn / sn;
                SCR = sn * qAlphaSCR / factor + sn * gamma1 * qAlphaSCR * qAlphaSCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
                MCR = sn * qAlphaMCR / factor + sn * gamma1 * qAlphaMCR * qAlphaMCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
                }
        } 
        insuranceContracts[Nt] = policy;
        emit InsuranceUnderwritten(Nt, msg.sender, T, stringToBytes32(station), l, cp, status, SCR, MCR);
    }

    function settle(uint256 contractId, uint256 Q_observed) public {
        InsuranceContract storage policy = insuranceContracts[contractId];
        require(policy.customer != address(0), "Invalid contract ID");
        require(msg.sender == owner, "Not authorized");
        require(policy.status == 0, "Contract is not active");
        
        modelPointsLogic.removeInsuranceContract(contractId, "closed");
        mu -= policy.p * policy.l * policy.eta / factor / factor;
        l_tot -= policy.l;
        Nt_MP_active = modelPointsLogic.Nt_MP_active();
        if (Nt_MP_active < Nt_MP_active_min) {
            SCR = l_tot;
            MCR = l_tot;
        }
        else {
            uint256 sn2 = modelPointsLogic.sn2();
            sn = sqrt(sn2);
            uint256 gamma1_unormalized = modelPointsLogic.gamma1_unormalized();
            gamma1 = gamma1_unormalized / sn / sn / sn;
            
            SCR = sn * qAlphaSCR / factor + sn * gamma1 * qAlphaSCR * qAlphaSCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
            MCR = sn * qAlphaMCR / factor + sn * gamma1 * qAlphaMCR * qAlphaMCR / factor / factor / 6 - sn * gamma1 / 6 - mu;
            }
        if (Q_observed >= 5) {
            sendPayout(payable(policy.customer), policy.l);
            policy.status = 1; // Settled with compensation
            updateReserveAfterSettlement(policy.l, policy.p, policy.eta, true);
            emit ClaimSettled(contractId, policy.customer, true, SCR, MCR);
        } else {
            updateReserveAfterSettlement(policy.l, policy.p, policy.eta, false);
            policy.status = 2; // Settled without compensation
            emit ClaimSettled(contractId, policy.customer, false, SCR, MCR);
            
        }    
        if (Xt < MCR) {
            refundPremiumToPolicyholders();
            if (Xt > 0){
                redistributeToInvestors();
            }
            SCR=0;
            MCR=0;
            sn=0;
            mu=0;
            gamma1=0;
            rt=10000;
            Xt=0;
            Nt_MP_active=0;
            modelPointsLogic.cancelAllActiveContracts();
        }
        
    }

    function updateReserveAfterSettlement(uint256 l, uint256 p, uint256 eta_S, bool settlement) internal {
        uint256 pp = (l * p) / factor;
        uint256 cp = (pp * (factor + eta_S)) / factor;
        if (settlement) {
            Xt += cp;
            Xt -= l;

        } else {
            Xt += cp;
        }
        rt = totalSupply > 0 ? (Xt * (factor)) / totalSupply : 1;
    }
    
    function refundPremiumToPolicyholders() internal {
        // require(Xt < MCR, "Reserve is above MCR");
        Xt = address(this).balance;
        require(Xt > 0, "Nothing to refund");
        uint256 TotalRefund = 0;
        uint256 ActivePolicyCount = 0;

        // Calculate total refund amount for active policies
        for (uint256 i = 1; i <= Nt; i++) {
            if (insuranceContracts[i].status == 0) { // Active contract
                TotalRefund += insuranceContracts[i].refund;
                ActivePolicyCount++;
            }
        }

        require(TotalRefund > 0, "No active policies to refund");

        // Check if the reserve is sufficient for full refunds
        if (Xt >= TotalRefund) {
            // Fully refund all policyholders
            for (uint256 i = 1; i <= Nt; i++) {
                if (insuranceContracts[i].status == 0) { // Active contract
                    uint256 refundAmount = insuranceContracts[i].refund;
                    insuranceContracts[i].status = 3; // Mark as refunded
                    modelPointsLogic.removeInsuranceContract(i, "cancelled");
                    sendPayout(payable(insuranceContracts[i].customer), refundAmount);
                    Xt -= refundAmount;
                }
            }
        } else {
            // Prorated refunds
            for (uint256 i = 1; i <= Nt; i++) {
                if (insuranceContracts[i].status == 0) { // Active contract
                    uint256 proratedRefund = (insuranceContracts[i].refund * Xt) / TotalRefund;
                    insuranceContracts[i].status = 3; // Mark as refunded
                    modelPointsLogic.removeInsuranceContract(i, "cancelled");
                    sendPayout(payable(insuranceContracts[i].customer), proratedRefund);
                }
            }
            Xt = 0; // All reserve used
        }
    }

    function redistributeToInvestors() internal {
        Xt = address(this).balance;
        require(Xt > 0, "Nothing to distribute");
        for (uint256 i = 0; i < investorAddresses.length; i++) {
            address investor = investorAddresses[i];
            uint256 investorShare = (Yt[investor] * Xt) / totalSupply;
            Yt[investor] = 0;
            if (investorShare > 0) {
                sendPayout(payable(investor), investorShare);
            }
        }
        Xt = 0; // All reserve distributed
        totalSupply = 0;
        delete investorAddresses;
    }

    function sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function sendPayout(address payable customer, uint256 l) internal {
        require(address(this).balance >= l, "Insufficient reserve for payout");
        (bool success, ) = customer.call{value: l}("");
        require(success, "Failed to send payout to policyholder");
    }
    
    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}