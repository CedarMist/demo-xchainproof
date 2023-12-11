// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {HeaderCache} from './HeaderCache.sol';
import {MerklePatriciaVerifier,RLP} from './lib/MerklePatriciaVerifier.sol';

contract AccountCache {
    struct Account {
        uint256 nonce;
        uint256 balance;
        bytes32 storageRoot;
        bytes32 codeHash;
    }

    /// Account not found in the cache for that block!
    error AccountNotFound(bytes32 headerHash, address accountAddress);

    mapping(bytes32 => mapping(address => Account)) private cachedAccounts;

    HeaderCache private headerCache;

    constructor (HeaderCache in_headerCache)
    {
        headerCache = in_headerCache;
    }

    function exists (bytes32 blockHash, address accountAddress)
        public view
        returns (bool)
    {
        return cachedAccounts[blockHash][accountAddress].storageRoot != bytes32(0);
    }

    function get (bytes32 blockHash, address accountAddress)
        public view
        returns (Account memory account)
    {
        account = cachedAccounts[blockHash][accountAddress];

        if( account.storageRoot == bytes32(0) )
        {
            revert AccountNotFound(blockHash, accountAddress);
        }
    }

    function verifyAccount (
        bytes32 stateRoot,
        address accountAddress,
        bytes memory rlpAccountProof
    )
        public pure
        returns (Account memory account)
    {
        bytes memory accountDetailsBytes = MerklePatriciaVerifier.getValueFromProof(stateRoot, keccak256(abi.encodePacked(accountAddress)), rlpAccountProof);

        RLP.Item[] memory accountDetails = RLP.toList(RLP.toItem(accountDetailsBytes));

        account.nonce = RLP.toUint(accountDetails[0]);
        account.balance = RLP.toUint(accountDetails[1]);
        account.storageRoot = RLP.toBytes32(accountDetails[2]);
        account.codeHash = RLP.toBytes32(accountDetails[3]);
    }

    function add (
        bytes32 blockHash,
        address accountAddress,
        bytes memory rlpAccountProof
    )
        public
        returns (Account memory account)
    {
        HeaderCache.Header memory header = headerCache.get(blockHash);

        if( ! exists(blockHash, accountAddress) )
        {
            account = verifyAccount(header.stateRoot, accountAddress, rlpAccountProof);

            cachedAccounts[blockHash][accountAddress] = account;
        }
        else {
            account = get(blockHash, accountAddress);
        }
    }
}
