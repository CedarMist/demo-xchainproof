// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {MerklePatriciaVerifier,RLP} from './lib/MerklePatriciaVerifier.sol';

import {AccountCache} from './AccountCache.sol';

contract StorageProof {
    AccountCache private accountCache;

    constructor (AccountCache in_accountCache)
    {
        accountCache = in_accountCache;
    }

    function verifyStorage(
        bytes32 blockHash,
        address accountAddress,
        uint256 slot,
        bytes32 key,
        bytes memory rlpStorageProof
    )
        public view
        returns (bytes32 data)
    {
        AccountCache.Account memory account = accountCache.get(blockHash, accountAddress);

        bytes32 storageKey = keccak256(abi.encodePacked(key, slot));

        bytes memory accountDetailsBytes = MerklePatriciaVerifier.getValueFromProof(account.storageRoot, keccak256(abi.encodePacked(storageKey)), rlpStorageProof);

        return RLP.toBytes32(RLP.toItem(accountDetailsBytes));
    }
}
