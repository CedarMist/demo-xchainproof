// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Host,Endpoint,Result} from '@oasisprotocol/sapphire-contracts/contracts/OPL.sol';

import {StorageProof} from './StorageProof.sol';

struct VotingSpec {
    /// Proofs of token balance must be provided for this specific block hash
    bytes32 blockHash;

    /// Address of contract which holds weighted balances for voting
    address tokenContract;

    /// Which storage slot holds the account balances
    uint256 tokenBalanceSlot;

    /// Total number of tokens available to vote
    uint256 tokenTotalSupply;

    uint256 proposalId;
}

contract VotingHost is Host
{
    constructor(address enclaveContract)
        Host(enclaveContract)
    {
        registerEndpoint('finishPoll', _finishPoll);
    }

    function createPoll (
        VotingSpec memory spec
    )
        external
    {
        // Auto-fill blockHash with most recently mined block
        if( spec.blockHash == bytes32(0) )
        {
            spec.blockHash = blockhash(block.number - 1);
        }

        postMessage('createPoll', abi.encode(spec));
    }

    function _finishPoll(bytes calldata in_data)
        internal
        returns (Result)
    {
        // TODO: tally votes
    }
}

contract VotingSapphire is Endpoint
{
    StorageProof private storageProof;

    mapping(bytes32 => VotingSpec) private proposals;

    constructor(
        StorageProof in_storageProof,
        address in_remoteContract,
        bytes32 in_remoteChainName
    )
        Endpoint(in_remoteContract, in_remoteChainName)
    {
        registerEndpoint('createPoll', _createPoll);
    }

    function _createPoll(bytes calldata data)
        internal
        returns (Result)
    {
        VotingSpec memory spec = abi.decode(data, (VotingSpec));

        bytes32 proposalHash = keccak256(data);

        proposals[proposalHash] = spec;

        return Result.Success;
    }

    function _vote(bytes32 proposalHash, address accountAddress, bytes memory rlpStorageProof)
        internal
    {
        VotingSpec memory spec = proposals[proposalHash];

        require( spec.blockHash != bytes32(0) );

        uint256 weight = uint256(storageProof.verifyStorage(
            spec.blockHash,
            spec.tokenContract,
            spec.tokenBalanceSlot,
            bytes20(accountAddress),
            rlpStorageProof));

        require( weight != 0 );

        // TODO: implement voting mechanism
    }

    function vote(bytes32 proposalHash, bytes memory rlpStorageProof)
        external
    {
        _vote(proposalHash, msg.sender, rlpStorageProof);
    }

    function finish (bytes32 proposalHash)
        external
    {
        VotingSpec memory spec = proposals[proposalHash];

        // TODO: verify proposal has finished

        postMessage('finishPoll', abi.encode(spec.proposalId));

        delete proposals[proposalHash];
    }
}
