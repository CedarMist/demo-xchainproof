// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RLP } from "./RLP.sol";

/*
MIT License

Copyright (c) 2017 Sam Mayo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/*
 * @title MerklePatriciaVerifier
 * @author Sam Mayo (sammayo888@gmail.com)
 *
 * @dev Library for verifing merkle patricia proofs.
 */
library MerklePatriciaVerifier {
	/*
	 * @dev Extracts the value from a merkle proof
	 * @param expectedRoot The expected hash of the root node of the trie.
	 * @param path The path in the trie leading to value.
	 * @param proofNodesRlp RLP encoded array of proof nodes.
	 * @return The value proven to exist in the merkle patricia tree whose root is `expectedRoot` at the path `path`
	 *
	 * WARNING: Does not currently support validation of unset/0 values!
	 */
	function getValueFromProof(bytes32 expectedRoot, bytes32 path, bytes memory proofNodesRlp) internal pure returns (bytes memory) {
		RLP.Item memory rlpParentNodes = RLP.toItem(proofNodesRlp);
		RLP.Item[] memory parentNodes = RLP.toList(rlpParentNodes);

		bytes memory currentNode;
		RLP.Item[] memory currentNodeList;

		bytes32 nodeKey = expectedRoot;
		uint pathPtr = 0;

		// our input is a 32-byte path, but we have to prepend a single 0 byte to that and pass it along as a 33 byte memory array since that is what getNibbleArray wants
		bytes memory nibblePath = new bytes(33);
		assembly { mstore(add(nibblePath, 33), path) }
		nibblePath = _getNibbleArray(nibblePath);

		require(path.length != 0, "empty path provided");

		currentNode = RLP.toBytes(parentNodes[0]);

		for (uint i=0; i<parentNodes.length; i++) {
			require(pathPtr <= nibblePath.length, "Path overflow");

			currentNode = RLP.toBytes(parentNodes[i]);
			require(nodeKey == keccak256(currentNode), "node doesn't match key");
			currentNodeList = RLP.toList(parentNodes[i]);

			if(currentNodeList.length == 17) {
				if(pathPtr == nibblePath.length) {
					return RLP.toData(currentNodeList[16]);
				}

				uint8 nextPathNibble = uint8(nibblePath[pathPtr]);
				require(nextPathNibble <= 16, "nibble too long");
				nodeKey = RLP.toBytes32(currentNodeList[nextPathNibble]);
				pathPtr += 1;
			} else if(currentNodeList.length == 2) {
				pathPtr += _nibblesToTraverse(RLP.toData(currentNodeList[0]), nibblePath, pathPtr);
				// leaf node
				if(pathPtr == nibblePath.length) {
					return RLP.toData(currentNodeList[1]);
				}
				//extension node
				require(_nibblesToTraverse(RLP.toData(currentNodeList[0]), nibblePath, pathPtr) != 0, "invalid extension node");

				nodeKey = RLP.toBytes32(currentNodeList[1]);
			} else {
				require(false, "unexpected length array");
			}
		}
		require(false, "not enough proof nodes");
	}

	function _nibblesToTraverse(bytes memory encodedPartialPath, bytes memory path, uint pathPtr) private pure returns (uint) {
		uint len;
		// encodedPartialPath has elements that are each two hex characters (1 byte), but partialPath
		// and slicedPath have elements that are each one hex character (1 nibble)
		bytes memory partialPath = _getNibbleArray(encodedPartialPath);
		bytes memory slicedPath = new bytes(partialPath.length);

		// pathPtr counts nibbles in path
		// partialPath.length is a number of nibbles
		for(uint i=pathPtr; i<pathPtr+partialPath.length; i++) {
			bytes1 pathNibble = path[i];
			slicedPath[i-pathPtr] = pathNibble;
		}

		if(keccak256(partialPath) == keccak256(slicedPath)) {
			len = partialPath.length;
		} else {
			len = 0;
		}
		return len;
	}

	// bytes byteArray must be hp encoded
	function _getNibbleArray(bytes memory byteArray) private pure returns (bytes memory) {
		bytes memory nibbleArray;
		if (byteArray.length == 0) return nibbleArray;

		uint8 offset;
		uint8 hpNibble = uint8(_getNthNibbleOfBytes(0,byteArray));
		if(hpNibble == 1 || hpNibble == 3) {
			nibbleArray = new bytes(byteArray.length*2-1);
			bytes1 oddNibble = _getNthNibbleOfBytes(1,byteArray);
			nibbleArray[0] = oddNibble;
			offset = 1;
		} else {
			nibbleArray = new bytes(byteArray.length*2-2);
			offset = 0;
		}

		for(uint i=offset; i<nibbleArray.length; i++) {
			nibbleArray[i] = _getNthNibbleOfBytes(i-offset+2,byteArray);
		}
		return nibbleArray;
	}

	function _getNthNibbleOfBytes(uint n, bytes memory str) private pure returns (bytes1) {
		return bytes1(n%2==0 ? uint8(str[n/2])/0x10 : uint8(str[n/2])%0x10);
	}
}
