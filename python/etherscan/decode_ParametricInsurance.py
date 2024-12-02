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
        contractId = int(topics[1], 16)
        customer_address =  '0x' + topics[2][26:]  # Strip the first 26 characters (leading zeros and '0x')
        EventDescription = bytes.fromhex(topics[3][2:]).decode('utf-8').rstrip('\x00')

        # # The ABI types for the non-indexed parameters
        abi_types = ['uint256', 'uint8']
        # # Decode the data field
        decoded_data = decode(abi_types, decode_hex(data))

        return {
            'event': event_name,
            'contractId': contractId,
            'customer_address': customer_address,
            'EventDescription': EventDescription,
            'payoutAmount': decoded_data[0],
            'status': decoded_data[1],
            }
    
    elif event_name == "ClaimSettled":
        contractId = int(topics[1], 16)
        customer_address =  '0x' + topics[2][26:]  # Strip the first 26 characters (leading zeros and '0x')
        

        # # The ABI types for the non-indexed parameters
        abi_types = ['bool', 'uint256']

        # # Decode the data field
        decoded_data = decode(abi_types, decode_hex(data))

        return({
            'event': event_name,
            'contractId': contractId,
            'customer_address': customer_address,
            'payoutTransfered': decoded_data[0],
            'Xt': decoded_data[1]
        })

    elif event_name == "ParametersUpdated":
        # contractId = int(topics[1], 16)
        # customer_address =  '0x' + topics[2][26:]  # Strip the first 26 characters (leading zeros and '0x')
        

        # # The ABI types for the non-indexed parameters
        abi_types = ['uint16', 'uint16', 'uint16', 'uint16']

        # # Decode the data field
        decoded_data = decode(abi_types, decode_hex(data))

        return {
            'event':event_name,
            'eta1': decoded_data[0],
            'eta2': decoded_data[1],
            'qAlphaSCR': decoded_data[2],
            'qAlphaMCR': decoded_data[3],
            }