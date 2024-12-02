from dataclasses import dataclass
from typing import Union
import hashlib
from Crypto.Hash import keccak

@dataclass
class InsuranceContract:
    customer: str  # Address of the policyholder (represented as a string in Python)
    event_description: bytes  # Description of the insured event (bytes32 in Solidity corresponds to bytes in Python)
    l: int  # Payout amount (uint256 corresponds to int in Python)
    p: int  # Probability of the event (uint256 corresponds to int in Python)
    eta: int  # Loading of the premium at the underwriting time (uint16 corresponds to int in Python)
    refund: int  # Refund amount in case of bankruptcy (uint256 corresponds to int in Python)
    status: int  # Status of the contract (0 = open, 1 = closed and settled, 2 = closed without compensation, 3 = refunded)




def get_random_number(event_description: str) -> int:
    """
    Generate a pseudo-random number based on the event description using keccak256.
    
    Parameters:
        event_description (str): The description of the event.

    Returns:
        int: A pseudo-random number in the range [0, 10000].
    """
    # Create a keccak256 hash of the event description
    keccak_hash = keccak.new(digest_bits=256)
    keccak_hash.update(event_description.encode())
    
    # Convert the hash to an integer
    random_number = int(keccak_hash.hexdigest(), 16)
    
    # Limit the random number to the range [0, 10000]
    return random_number % 10001 / 10000

