// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract ParametricInsurance {
    address public owner; // Ethereum address of the owner of the contract
    uint256 public constant factor = 10 ** 4; // Numerical precision
    uint256 public totalSupply; // Total supply of tokens
    uint256 public rt = 10000; // Exchange rate of token against ETH
    uint256 public sn2 = 0; // Variance of the liability
    uint256 public mu = 0; // cumulative premium in excess of the pure premium  
    uint256 public SCR = 0; // Value of the Solvency Capital Requirement
    uint256 public MCR = 0; // Value of the Minimum Capital Requirement
    uint256 public Xt; // Reserve to calculate the exchange rate
    uint16 public eta1 = 1000; // 10% loading (1000 basis points) to reward the token holders
    uint16 public eta2 = 500; // 5% loading (500 basis points) to reward the policyholders
    uint16 public qAlphaSCR = 25758; // standard normal quantile of order alpha = 0.995
    uint16 public qAlphaMCR = 10364; // standard normal quantile of order alpha = 0.995
    uint256 public Nt; // Counter for the number of insurance contracts

    struct InsuranceContract {
        address customer; // Address of the policyholder
        bytes32 EventDescription; // Description of the insured event
        uint256 l; // Payout amount
        uint256 p; // Probability of the event
        uint16 eta; // loading of the premium at the underwritting time
        uint256 refund; // Refund amount in case of bankruptcy
        uint8 status; // Status of the contract 0 = open, 1 = closed and settled, 2 = closed without compensation, 3 = refunded
    }

    address[] public investorAddresses; // Array to store investor addresses

    mapping(uint256 => InsuranceContract) public insuranceContracts; // Mapping of insurance contracts
    mapping(address => uint256) public Yt; // Balance of investors in tokens
    
    event ParametersUpdated(uint16 newEta1, uint16 newEta2, uint16 newQAlphaSCR, uint16 newQAlphaMCR);
    event Fund(address indexed from, uint256 x, uint256 y);
    event Burn(address indexed from, uint256 x, uint256 y);
    event InsuranceUnderwritten(uint256 indexed contractId, address indexed customer, 
    bytes32 indexed EventDescription, uint256 payoutAmount, uint8 status);
    event ClaimSettled(uint256 indexed contractId, address indexed customer, bool payoutTransferred, uint256 Xt);

    

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}
    
    function updateParameters(uint16 newEta1, uint16 newEta2, uint16 newQAlphaSCR, uint16 newQAlphaMCR) public {
    require(msg.sender == owner, "Only the owner can update parameters");
    eta1 = newEta1;
    eta2 = newEta2;
    qAlphaSCR = newQAlphaSCR;
    qAlphaMCR = newQAlphaMCR;
    SCR = (sqrt(sn2) * qAlphaSCR) / factor   - mu;
    MCR = (sqrt(sn2) * qAlphaMCR) / factor   - mu;
    if (Xt < MCR) {
            refundPremiumToPolicyholders();
            if (Xt > 0){
                redistributeToInvestors();
            }
            SCR=0;
            MCR=0;
            sn2=0;
            mu=0;
            rt=10000;
            Xt=0;
        }

    emit ParametersUpdated(newEta1, newEta2, newQAlphaSCR, newQAlphaMCR);
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

        function getQuote(string memory EventDescription, uint256 l) public view returns (uint256) {
        uint256 p = getRandomNumber(EventDescription);
        uint256 pp = (l * p) / factor;
        uint256 cp = (pp * (factor + eta1 + eta2)) / factor;
        return cp;
    }

    function underwritePolicy(string memory EventDescription, uint256 l) public payable {
        uint16 eta = eta1 + eta2;
        uint256 p = getRandomNumber(EventDescription);
        uint256 pp = (l * p) / factor;
        uint256 cp = (pp * (factor + eta)) / factor;
        uint256 cp1 = (pp * (factor + eta1)) / factor;
        sn2 += (l * l) * p * (factor-p) / factor / factor;
        mu += p * l * eta / factor / factor;

        SCR = (sqrt(sn2) * qAlphaSCR) / factor   - mu;
        MCR = (sqrt(sn2) * qAlphaMCR) / factor   - mu;
        uint256 tokensToMint = (eta2 * pp) / rt;
        totalSupply += tokensToMint;
        if (Yt[msg.sender] == 0) {
            investorAddresses.push(msg.sender);
            }
        Yt[msg.sender] += tokensToMint;
        


        rt = totalSupply > 0 ? (Xt * (factor)) / totalSupply : 1;

        require(msg.value == cp, "Incorrect premium amount sent");
        require(SCR <= Xt, "Payout amount exceeds reserve");

        (bool success, ) = payable(address(this)).call{value: msg.value}("");
        require(success, "Failed to transfer premium to reserve");

           
        Nt++;
        

        InsuranceContract memory policy = InsuranceContract({
            customer: msg.sender,
            EventDescription: stringToBytes32(EventDescription),
            l: l,
            p:p,
            eta: eta,
            refund:cp1,
            status: 0
        });

        insuranceContracts[Nt] = policy;
    
        emit InsuranceUnderwritten(Nt, msg.sender, stringToBytes32(EventDescription), l, 0);
    
    }

    function settle(uint256 contractId, string memory EventObserved) public {
        InsuranceContract storage policy = insuranceContracts[contractId];
        uint256 pObserved = getRandomNumber(EventObserved);
        

        require(policy.customer != address(0), "Invalid contract ID");
        require(msg.sender == owner || msg.sender == policy.customer, "Not authorized");
        require(policy.status == 0, "Contract is not active");

        if (pObserved < policy.p) {
            sendPayout(payable(policy.customer), policy.l);
            policy.status = 1; // Settled with compensation
            updateReserveAfterSettlement(policy.l, policy.p, policy.eta, true);
            emit ClaimSettled(contractId, policy.customer, true, Xt);
        } else {
            updateReserveAfterSettlement(policy.l, policy.p, policy.eta, false);
            policy.status = 2; // Settled without compensation
            emit ClaimSettled(contractId, policy.customer, false, Xt);
        }
        if (Xt < MCR) {
            refundPremiumToPolicyholders();
            if (Xt > 0){
                redistributeToInvestors();
            }
            SCR=0;
            MCR=0;
            sn2=0;
            mu=0;
            rt=10000;
            Xt=0;
            
        }
    }

    function updateReserveAfterSettlement(uint256 l, uint256 p, uint256 eta, bool settlement) internal {
        uint256 pp = (l * p) / factor;
        uint256 cp = (pp * (factor + eta)) / factor;
        if (settlement) {
            Xt += cp;
            Xt -= l;

        } else {
            Xt += cp;
        }
        sn2 -= (l * l) * p * (factor-p) / factor / factor ;
        mu -= p * l * eta / factor / factor;
        SCR = (sqrt(sn2) * qAlphaSCR) / factor   - mu ;
        MCR = (sqrt(sn2) * qAlphaMCR) / factor   - mu ;
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
    function getRandomNumber(string memory EventDescription) public pure returns (uint) {
        // Generate a hash based only on flightNumber and departureDate
        uint randomHash = uint(keccak256(abi.encodePacked(EventDescription)));
        
        // Limit the random number to the range [0, 10000]
        return randomHash % 10001;
    }
}