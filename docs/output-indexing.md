# Output Indexing

This document specifies the changes necessary to implement the Output Indexing feature.

## 1. Motivation

The Rollups Node JSON-RPC request `cartesi_listOutputs` allows listing outputs emitted by an application and filtering them by output type and voucher destination. For example, the request below lists the first 50 outputs of the type "voucher" (identified by the selector `0x237a816f`), emitted by the application `my-app`, and targetting the address `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`.

```json
{
  "method": "cartesi_listOutputs",
  "params": {
    "application": "my-app",
    "output_type": "0x237a816f",
    "voucher_address": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "limit": 50,
    "offset": 0
  }
}
```

However, for some basic use cases, the filtering options available are not enough. One classic example is filtering vouchers by recipient address. For Ether transfers, we can filter vouchers by destination address, as shown in the example above. However, for other asset types, the recipient address is buried in the voucher payload, which the node cannot properly index. In order for the Rollups Node to properly index outputs, they must have a top-level structure with indexed fields at known offsets. Rest assured, any arbitrary byte array would still be accepted as output by the Rollups Node and validated by the Rollups Contracts. However, arbitrary byte arrays might not leverage the indexing capabilities provided by the Rollups Node.

## 2. Top-Level Structure and Encoding

Outputs contain an array of 1-4 arguments and a binary payload. Arguments are 32-byte values meant for indexing, while the data field encodes non-indexed information. Outputs can be filtered by equality checks on arguments, as in "List all outputs with A as arg #0 and B as arg #1". Indexed outputs are still encoded as Solidity function calls, although the set of valid function signatures is now restricted to a small family of four:

```solidity
function Output1(bytes32[1] calldata args, bytes calldata data) external;
function Output2(bytes32[2] calldata args, bytes calldata data) external;
function Output3(bytes32[3] calldata args, bytes calldata data) external;
function Output4(bytes32[4] calldata args, bytes calldata data) external;
```

The encoding of an output with `N` arguments starts with a 4-byte function selector (the first 4 bytes of the Keccak-256 hash of the string `OutputN(bytes32[N],bytes)`), followed by `args` and `data` encoded in accordance to the standard Solidity ABI. Since `args` is a fixed-size array of 32-byte values, its elements (`arg0`, `arg1`, ..., `arg{N-1}`) sit inline immediately after the function selector. In contrast, since `data` is a variable-length `bytes` value, its contents are right-padded with the least amount of zeroes that makes its size a multiple of 32 bytes, and prefixed with a 32-byte offset (which is a constant for each function) and a 32-byte length. Note that Solidity is being used in this context merely as an interface description language (IDL). These functions are not implemented by any smart contract that is part of the Rollups Contracts suite.

| 0xaed682a1 (Output1) | arg0 | 0x40 (offset) | length | data |
|---|---|---|---|---|
| 4 bytes | 32 bytes | 32 bytes | 32 bytes | $32 \cdot \left\lceil \frac{\text{left}}{32} \right\rceil$ bytes |

| 0x50b41f12 (Output2) | arg0 | arg1 | 0x60 (offset) | length | data |
|---|---|---|---|---|---|
| 4 bytes | 32 bytes | 32 bytes | 32 bytes | 32 bytes | $32 \cdot \left\lceil \frac{\text{left}}{32} \right\rceil$ bytes |

| 0x1cd62f99 (Output3) | arg0 | arg1 | arg2 | 0x80 (offset) | length | data |
|---|---|---|---|---|---|---|
| 4 bytes | 32 bytes | 32 bytes | 32 bytes | 32 bytes | 32 bytes | $32 \cdot \left\lceil \frac{\text{left}}{32} \right\rceil$ bytes |

| 0x77edf709 (Output4) | arg0 | arg1 | arg2 | arg3 | 0xa0 (offset) | length | data |
|---|---|---|---|---|---|---|---|
| 4 bytes | 32 bytes | 32 bytes | 32 bytes | 32 bytes | 32 bytes | 32 bytes | $32 \cdot \left\lceil \frac{\text{left}}{32} \right\rceil$ bytes |

The selector picks the argument count, and argument offsets are therefore uniform across every envelope that has that argument:

| Field | Byte range (1-indexed) | Present in |
|---|---|---|
| Function selector | `1..4` | all |
| `arg0` | `5..36` | `Output1`..`Output4` |
| `arg1` | `37..68` | `Output2`..`Output4` |
| `arg2` | `69..100` | `Output3`..`Output4` |
| `arg3` | `101..132` | `Output4` |

Meanwhile, the offset, length, and data fields, present in all indexed outputs, have different byte ranges for each function signature.

| Function name | Offset byte range (1-indexed) | Length byte range (1-indexed) | Data byte range (1-indexed) |
|---|---|---|---|
| `Output1` | `37..68` | `69..100` | `101..` |
| `Output2` | `69..100` | `101..132` | `133..` |
| `Output3` | `101..132` | `133..164` | `165..` |
| `Output4` | `133..164` | `165..196` | `197..` |

The Rollups Node can check the offset and length fields for consistency and fallback to handling output as an opaque blob on failure. For example: `Output1` cannot have an `offset` different from `0x40`, and the size of the whole `Output1` output must be `100 + 32*ceil(length/32)`. Moreover, `data` must be padded to the smallest multiple of 32 bytes no smaller than `length`.

## 3. Canonical Output Encoding

Currently, the v2 Rollups Contracts define three canonical outputs: notices, CALL vouchers, and DELEGATECALL vouchers. This section specifies
how they are encoded in the new format, and introduces new asset-transfer executable outputs with indexed asset-specific fields. The application contract will understand these new executable outputs and execute them in-line.

Instead of the 4-byte selector, we now use `arg0` to identify the output kind. In order to avoid collisions, we use the Keccak-256 hash of descriptive strings as `arg0`. Below are all descriptive strings used and their hashes.

```solidity
// 0xe4f5829fb698a59fba2cf6128b6bf1e8ce1dc09d271c55b787781bd415db8eed
bytes32 constant NOTICE = keccak256("cartesi.output.v1.notice"); 

// 0xd515b20044ba3bb84cfce3004f8b64ee11fb8ca22f936e4bc25a65e4b2133120
bytes32 constant CALL_VOUCHER = keccak256("cartesi.output.v1.call-voucher"); 

// 0xe166d466bf2d7d71d7f3f69e4c68f516330d8073b6ddb408c507548b64a1f3bb
bytes32 constant DELEGATECALL_VOUCHER = keccak256("cartesi.output.v1.delegatecall-voucher"); 

// 0x75eead9621dd1a27723e3804c02737adc17f589115bb13b7452f57be9538698b
bytes32 constant ETHER_TRANSFER = keccak256("cartesi.output.v1.ether-transfer"); 

// 0x0aee4bb11857d8ad0054824e55c20c8904f13d1d06da54603de2aada50555484
bytes32 constant ERC20_TRANSFER = keccak256("cartesi.output.v1.erc20-transfer"); 

// 0xe193e9e84bbdcc6f38aa95abb77afa3c00ab0e7e968803cb65fc636b428e4fad
bytes32 constant ERC721_TRANSFER = keccak256("cartesi.output.v1.erc721-transfer"); 

// 0x215e4e53412c5e8dbc6f458ba04e08a5420b6fde887e062f52ca008867073710
bytes32 constant ERC1155_SINGLE_TRANSFER = keccak256("cartesi.output.v1.erc1155-single-transfer"); 

// 0xacb78f74c14ee09ed60b72d40e226f6b9935acd71fab6dbec717dfff2b7bb85f
bytes32 constant ERC1155_BATCH_TRANSFER = keccak256("cartesi.output.v1.erc1155-batch-transfer"); 
```

In this text, we will use the constant names as a shorthand for their values. Besides `arg0`, some canonical outputs also use `arg1` and `arg2` for protocol-level indexing purposes. Vouchers, for instance, use `arg1` for indexing the destination address. Meanwhile, some arguments are unused and therefore free for applications to use for their own purposes. If an application wishes to emit a canonical output with extra arguments, they must use a larger envelope and use the arguments after the protocol-level ones. For example: a notice with one extra argument will use envelope `Output2` (instead of `Output1`) and place the extra argument at `arg1` (after the already taken `arg0`). Note that `arg0` and `data` are unchanged. The same could be done for executable outputs, and the application contract would seamlessly decode an envelope larger than the canonical one.

### 3.1. Notices

- `payload`: `bytes` - Arbitrary notice payload

Generic piece of information. Now encoded as:

- Envelopes: `Output1`..`Output4`
- `arg0`: `NOTICE`
- `arg1` (optional): Application-specific
- `arg2` (optional): Application-specific
- `arg3` (optional): Application-specific
- `data`: `payload`

### 3.2. CALL Vouchers

- `destination`: `address` - The address that will be called
- `value`: `uint256` - The amount of Wei to be transferred through the call
- `payload`: `bytes` - The payload, which—in the case of Solidity contracts—encodes a function call

Executes a generic `CALL` instruction from the context of the application contract. Just like before, we are still able to filter CALL vouchers by destination address (now encoded as `arg1`). Vouchers were renamed to CALL vouchers to draw a clearer distinction from DELEGATECALL vouchers. They are now encoded like so:

- Envelopes: `Output2`..`Output4`
- `arg0`: `CALL_VOUCHER`
- `arg1`: `bytes32(uint256(uint160(destination)))`
- `arg2` (optional): Application-specific
- `arg3` (optional): Application-specific
- `data`: `abi.encode(value, payload)`

### 3.3. DELEGATECALL Vouchers

- `destination`: `address` - The address that will be called
- `payload`: `bytes` - The payload, which—in the case of Solidity libraries—encodes a function call

Execute a generic `DELEGATECALL` instruction from the context of the application contract. We are now able to filter DELEGATECALL vouchers by destination address as well (through `arg1`). They are now encoded like so:

- Envelopes: `Output2`..`Output4`
- `arg0`: `DELEGATECALL_VOUCHER`
- `arg1`: `bytes32(uint256(uint160(destination)))`
- `arg2` (optional): Application-specific
- `arg3` (optional): Application-specific
- `data`: `payload`

### 3.4. Ether Transfers

- `recipient`: `address` - The address of the Ethereum account that will receive the amount of Ether
- `value`: `uint256` - The amount of Wei to be transferred to the recipient

(New!) Transfers Ether locked in the application contract to an Ethereum account. More precisely, it sends the amount of Ether to the recipient address through a message call with an empty payload and ensures the call succeeds. They can be filtered by recipient address.

- Envelopes: `Output2`..`Output4`
- `arg0`: `ETHER_TRANSFER`
- `arg1`: `bytes32(uint256(uint160(recipient)))`
- `arg2` (optional): Application-specific
- `arg3` (optional): Application-specific
- `data`: `abi.encode(value)`

### 3.5. ERC-20 Transfers

- `recipient`: `address` - The address of the Ethereum account that will receive the ERC-20 token(s)
- `token`: `address` - The address of the ERC-20 token contract
- `value`: `uint256` - The amount of ERC-20 tokens to be transferred to the recipient

(New!) Transfers ERC-20 token(s) locked in the application contract to an Ethereum account. More precisely, it calls `IERC20(token).transfer(recipient, value)` and ensures either nothing (empty return data) or `true` is returned. We can filter them by recipient address and by token contract address.

- Envelopes: `Output3`..`Output4`
- `arg0`: `ERC20_TRANSFER`
- `arg1`: `bytes32(uint256(uint160(recipient)))`
- `arg2`: `bytes32(uint256(uint160(token)))`
- `arg3` (optional): Application-specific
- `data`: `abi.encode(value)`

### 3.6. ERC-721 Transfers

- `recipient`: `address` - The address of the Ethereum account that will receive the ERC-721 token
- `token`: `address` - The address of the ERC-721 token contract
- `tokenId`: `uint256` - The ID of ERC-721 token to be transferred to the recipient

(New!) Transfers an ERC-721 token locked in the application contract to an Ethereum account. More precisely, it calls `IERC721(token).safeTransferFrom(appContract, recipient, tokenId)`. We can filter them by recipient address and by token contract address.

- Envelope: `Output3`..`Output4`
- `arg0`: `ERC721_TRANSFER`
- `arg1`: `bytes32(uint256(uint160(recipient)))`
- `arg2`: `bytes32(uint256(uint160(token)))`
- `arg3` (optional): Application-specific
- `data`: `abi.encode(tokenId)`

### 3.7. ERC-1155 Single Transfers

- `recipient`: `address` - The address of the Ethereum account that will receive the ERC-1155 token(s)
- `token`: `address` - The address of the ERC-1155 token contract
- `tokenId`: `uint256` - The ID of ERC-1155 token(s) to be transferred to the recipient
- `value`: `uint256` - The amount of ERC-1155 tokens to be transferred to the recipient

(New!) Transfers ERC-1155 token(s) of a single ID locked in the application contract to an Ethereum account. More precisely, it calls `IERC1155(token).safeTransferFrom(appContract, recipient, tokenId, value, "")`. We can filter them by recipient address and by token contract address.

- Envelope: `Output3`..`Output4`
- `arg0`: `ERC1155_SINGLE_TRANSFER`
- `arg1`: `bytes32(uint256(uint160(recipient)))`
- `arg2`: `bytes32(uint256(uint160(token)))`
- `arg3` (optional): Application-specific
- `data`: `abi.encode(tokenId, value)`

### 3.8. ERC-1155 Batch Transfers

- `recipient`: `address` - The address of the Ethereum account that will receive the ERC-1155 token(s)
- `token`: `address` - The address of the ERC-1155 token contract
- `tokenIdsAndValues`: `(uint256,uint256)[]` - The IDs and amounts of ERC-1155 token(s) to be transferred to the recipient

(New!) Transfers ERC-1155 token(s) of multiple IDs locked in the application contract to an Ethereum account. More precisely, it calls `IERC1155(token).safeBatchTransferFrom(appContract, recipient, tokenIds, values, "")`. We can filter them by recipient address and by token contract address.

- Envelopes: `Output3`..`Output4`
- `arg0`: `ERC1155_BATCH_TRANSFER`
- `arg1`: `bytes32(uint256(uint160(recipient)))`
- `arg2`: `bytes32(uint256(uint160(token)))`
- `arg3` (optional): Application-specific
- `data`: `abi.encode(tokenIdsAndValues)`

## 4. Contract Impact

This feature introduces breaking changes in the Rollups Contracts v2 Output ABI.

| Contract | Impact |
|---|---|
| `common/Outputs.sol` | Replace the three output functions with the `Output1`..`Output4` top-level envelopes and define the canonical output `arg0` values. |
| `dapp/Application.sol` | Match the `Output1`..`Output4` selector, decode `(bytes32[N] args, bytes data)`, match `arg0`, and perform each executable output. |
| `withdrawal/UsdWithdrawalOutputBuilder.sol` | Encode ERC-20 transfer output in new format. |
