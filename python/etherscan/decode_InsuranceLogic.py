from eth_abi import decode
from eth_utils import decode_hex

def decode_event(event, event_signature_hashes_dict):
    topics, data = event['topics'], event['data']

# Event Signature (InsuranceUnderwritten event)
    event_signature_hash = topics[0]
    event_name = event_signature_hashes_dict[event_signature_hash]
    if event_name == "Fund" or event_name == "Burn":
        investor_address = '0x' + topics[1][26:]  # Strip the first 26 characters (leading zeros and '0x')
        # The ABI types for the non-indexed parameters
        abi_types = ['uint256', 'uint256']

        # Decode the data field
        decoded_data = decode(abi_types, decode_hex(data))
        
        return {
            'event': event_name,
            'investor_address': investor_address,
            'x': decoded_data[0],
            'y': decoded_data[1]
            }
    elif event_name == "InsuranceUnderwritten":

        topics, data = event['topics'], event['data']

        event_signature_hash = topics[0]
        event_name = event_signature_hashes_dict[event_signature_hash]
        contractId = int(topics[1], 16)

        customer_address =  '0x' + topics[2][26:]  # Strip the first 26 characters (leading zeros and '0x')
        customer_address
        abi_types = ['uint256', 'bytes32','uint256', 'uint256','uint8', 'uint256', 'uint256']
        decoded_data = decode(abi_types, decode_hex(data))
        decoded_data

        return {
            'event': event_name,
            'contractId': contractId,
            'customer_address': customer_address,
            'T': decoded_data[0],
            'station': decoded_data[1].decode('utf-8').rstrip('\x00'),
            'l': decoded_data[2],    
            'cp': decoded_data[3],
            'status': decoded_data[4],
            'SCR': decoded_data[5],
            'MCR': decoded_data[6]
            }
    
    elif event_name == "ClaimSettled":
        contractId = int(topics[1], 16)
        customer_address =  '0x' + topics[2][26:]  # Strip the first 26 characters (leading zeros and '0x')
        

        # # The ABI types for the non-indexed parameters
        abi_types = ['bool', 'uint256', 'uint256']

        # # Decode the data field
        decoded_data = decode(abi_types, decode_hex(data))

        return({
            'event': event_name,
            'contractId': contractId,
            'customer_address': customer_address,
            'payoutTransfered': decoded_data[0],
            'SCR': decoded_data[1],
            'MCR': decoded_data[2]
        })

    elif event_name == "ParametersUpdated":
        # contractId = int(topics[1], 16)
        # customer_address =  '0x' + topics[2][26:]  # Strip the first 26 characters (leading zeros and '0x')
        

        # # The ABI types for the non-indexed parameters
        abi_types = ['uint16', 'uint16', 'uint16', 'uint256', 'uint256']

        # # Decode the data field
        decoded_data = decode(abi_types, decode_hex(data))

        return {
            'event':event_name,
            'eta': decoded_data[0],
            'qAlphaSCR': decoded_data[1],
            'qAlphaMCR': decoded_data[2],
            'SCR': decoded_data[3],
            'MCR': decoded_data[4]
            }
    

