import json
import eth_abi
from web3 import Web3


def get_transaction(transaction):
    if transaction["data"] is not None:
        raise ValueError("Data is not None")

    to = transaction["to"]
    value = int(transaction["value"])
    data = encode_tx_data(transaction)

    return {
        "to": to,
        "value": value,
        "data": data,
    }


def encode_tx_data(transaction):
    method = transaction["contractMethod"]
    input_values = transaction["contractInputsValues"]

    name = method["name"]

    types = []
    values = []

    for input in method["inputs"]:
        type = input["type"]
        value = input_values[input["name"]]

        if "[]" in type:
            value = value[1:-1].split(",")

            if "uint" in type:
                value = [int(v) for v in value]
        elif "uint" in type:
            value = int(value)

        types.append(type)
        values.append(value)

    name = f"{name}({','.join(types)})"
    selector = Web3.keccak(text=name)[:4].hex()

    data = eth_abi.encode(types, values)

    return f"{selector}{data.hex()}"


def main():
    with open("./encode_transactions/utils/Transactions Batch.json", "r") as f:
        transactions = json.load(f)["transactions"]

    data = []

    for transaction in transactions:
        data.append(get_transaction(transaction))

    dic = {"transactions": data}

    with open("./encode_transactions/utils/RawTransactions.json", "w") as f:
        json.dump(dic, f, indent=4)
