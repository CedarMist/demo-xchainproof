// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract HeaderCache {
    struct Header {
        bytes32 transactionRoot;
        bytes32 receiptsRoot;
        bytes32 stateRoot;
        uint256 blockTimestamp;
    }

    /// Header was not found in the cache
    error HeaderNotFound(bytes32 headerHash);

    /// Error while parsing header data
    error HeaderDataInvalid(bytes32 headerHash);

    mapping(bytes32 => Header) private cachedHeaders;

    /**
     * Extract the tree roots from the header
     *
     * @param rlpBytes RLP encoded Ethereum block header
     */
    function extractHeader (bytes memory rlpBytes)
        public pure
        returns (Header memory)
    {
        bytes32 stateRoot;
        bytes32 transactionRoot;
        bytes32 receiptsRoot;
        uint256 blockTimestamp;

        if( rlpBytes.length < 190 )
        {
            revert HeaderDataInvalid(keccak256(rlpBytes));
        }

        unchecked {
            assembly {
                function readDynamic(prefixPointer) -> dataPointer, dataLength {
                    let value := byte(0, mload(prefixPointer))
                    switch lt(value, 0x80)
                    case 1 {
                        dataPointer := prefixPointer
                        dataLength := 1
                    }
                    case 0 {
                        dataPointer := add(prefixPointer, 1)
                        dataLength := sub(value, 0x80)
                    }
                }

                // get the length of the data
                let rlpLength := mload(rlpBytes)
                // move pointer forward, ahead of length
                rlpBytes := add(rlpBytes, 0x20)

                // we know the length of the block will be between 483 bytes and 709 bytes, which means it will have 2 length bytes after the prefix byte, so we can skip 3 bytes in
                // CONSIDER: we could save a trivial amount of gas by compressing most of this into a single add instruction
                let parentHashPrefixPointer := add(rlpBytes, 3)
                let parentHashPointer := add(parentHashPrefixPointer, 1)
                let uncleHashPrefixPointer := add(parentHashPointer, 32)
                let uncleHashPointer := add(uncleHashPrefixPointer, 1)
                let minerAddressPrefixPointer := add(uncleHashPointer, 32)
                let minerAddressPointer := add(minerAddressPrefixPointer, 1)
                let stateRootPrefixPointer := add(minerAddressPointer, 20)
                let stateRootPointer := add(stateRootPrefixPointer, 1)
                let transactionRootPrefixPointer := add(stateRootPointer, 32)
                let transactionRootPointer := add(transactionRootPrefixPointer, 1)
                let receiptsRootPrefixPointer := add(transactionRootPointer, 32)
                let receiptsRootPointer := add(receiptsRootPrefixPointer, 1)
                let logsBloomPrefixPointer := add(receiptsRootPointer, 32)
                let logsBloomPointer := add(logsBloomPrefixPointer, 3)
                let difficultyPrefixPointer := add(logsBloomPointer, 256)
                let difficultyPointer, difficultyLength := readDynamic(difficultyPrefixPointer)
                let blockNumberPrefixPointer := add(difficultyPointer, difficultyLength)
                let blockNumberPointer, blockNumberLength := readDynamic(blockNumberPrefixPointer)
                let gasLimitPrefixPointer := add(blockNumberPointer, blockNumberLength)
                let gasLimitPointer, gasLimitLength := readDynamic(gasLimitPrefixPointer)
                let gasUsedPrefixPointer := add(gasLimitPointer, gasLimitLength)
                let gasUsedPointer, gasUsedLength := readDynamic(gasUsedPrefixPointer)
                let timestampPrefixPointer := add(gasUsedPointer, gasUsedLength)
                let timestampPointer, timestampLength := readDynamic(timestampPrefixPointer)

                stateRoot := mload(stateRootPointer)
                transactionRoot := mload(transactionRootPointer)
                receiptsRoot := mload(receiptsRootPointer)
                blockTimestamp := shr(sub(256, mul(timestampLength, 8)), mload(timestampPointer))
            }
        }

        if( transactionRoot == bytes32(0)
         || receiptsRoot == bytes32(0)
         || stateRoot == bytes32(0)
         || blockTimestamp == 0 )
        {
            revert HeaderDataInvalid(keccak256(rlpBytes));
        }

        return Header({
            transactionRoot: transactionRoot,
            receiptsRoot: receiptsRoot,
            stateRoot: stateRoot,
            blockTimestamp: blockTimestamp
        });
    }

    function exists (bytes32 headerHash)
        public view
        returns(bool)
    {
        return cachedHeaders[headerHash].transactionRoot != bytes32(0);
    }

    function get (bytes32 headerHash)
        public view
        returns (Header memory header)
    {
        header = cachedHeaders[headerHash];

        if( header.blockTimestamp == 0 )
        {
            revert HeaderNotFound(headerHash);
        }
    }

    function add (bytes memory headerRlpBytes)
        external
        returns (Header memory header)
    {
        bytes32 headerHash = keccak256(headerRlpBytes);

        if( ! exists(headerHash) )
        {
            header = extractHeader(headerRlpBytes);

            cachedHeaders[headerHash] = header;
        }
        else {
            return get(headerHash);
        }
    }
}
