# [Moe-Core](https://github.com/traderjoe-xyz/moe-core)

This repository contains the contracts, tests and deploy scripts for the Moe protocol.

After having pasted the `Transaction Batch.json` in the `./encode_transactions/utils/` folder, run the following commands to test the batch transactions:

```shell
$ poetry install
$ forge test --match-contract TestBatchTransactions --ffi -vvvv
```

## Poetry

This repository uses Poetry. The documentation can be found [here](https://python-poetry.org/docs/).

### Install

To install the dependencies, run:

```shell
$ poetry install
```

### Update

To update the dependencies, run:

```shell
$ poetry update
```

## Foundry

This repository uses Foundry. The documentation can be found [here](https://book.getfoundry.sh/).

### Build

To build the contracts, run:

```shell
$ forge build
```

### Test

To run the tests, run:

```shell
$ forge test
```

### Deploy

To deploy the contract, copy the `.env.example` to `.env` and fill in the values. Then run:

```shell
$ forge script script/<name_of_the_script> --broadcast --verify
```
