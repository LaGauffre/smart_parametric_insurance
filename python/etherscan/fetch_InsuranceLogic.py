# Fetching transactions and events ofthe RPToken contract
import requests
from web3 import Web3
from eth_hash.auto import keccak

# Etherscan API key
API_KEY = 'E3JHPGKI3NWIKTAJ46DB1898FZCSNS71HU'

# Contract address
CONTRACT_ADDRESS = '0xbe035cf1367c45A0C9517969F5ABDd3abF743ae7'

# Etherscan API URL
ETHERSCAN_API_URL = 'https://api-sepolia.etherscan.io/api'

# Function to get transactions of a contract
def get_transactions(contract_address, api_key):
    params = {
        'module': 'account',
        'action': 'txlist',
        'address': contract_address,
        'startblock': '0',
        'endblock': 'latest',
        'sort': 'asc',
        'apikey': api_key
    }
    response = requests.get(ETHERSCAN_API_URL, params=params)
    return response.json()

# Function to get events of a contract
def get_events(contract_address, api_key):
    params = {
        'module': 'logs',
        'action': 'getLogs',
        'address': contract_address,
        'fromBlock': '0',
        'toBlock': 'latest',
        'apikey': api_key
    }
    response = requests.get(ETHERSCAN_API_URL, params=params)
    return response.json()

# Retrieve transactions
transactions = get_transactions(CONTRACT_ADDRESS, API_KEY)
# print('Transactions:')
# print(transactions)

# Retrieve events
events = get_events(CONTRACT_ADDRESS, API_KEY)
# print('Events:')
print(events)

# Define the event signatures you want to map
event_signatures = [
    "ParametersUpdated(uint16,uint16,uint16,uint256,uint256)",
    "Fund(address,uint256,uint256)",
    "Burn(address,uint256,uint256)",
    "InsuranceUnderwritten(uint256,address,uint256,bytes32,uint256,uint256,uint8,uint256,uint256)",
    "ClaimSettled(uint256,address,bool,uint256,uint256)"
]
event_signatures_hashes = [f"0x{keccak(event_sig.encode()).hex()}" for event_sig in event_signatures]
event_signatures_hashes
# Create a dictionary with keys being event_signature_hashes and values being event names
event_signature_hashes_dict = dict(zip(event_signatures_hashes, ["ParametersUpdated", "Fund", "Burn", "InsuranceUnderwritten", "ClaimSettled"]))
