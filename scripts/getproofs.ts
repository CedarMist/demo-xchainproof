import { Network, Alchemy } from 'alchemy-sdk';
import { concat, getBytes, hexlify, keccak256, solidityPackedKeccak256, toBeHex, zeroPadBytes, zeroPadValue } from 'ethers';
import { Block } from '@ethereumjs/block';
import { Common, CustomChain } from '@ethereumjs/common';
import { assert } from 'console';

import { settings } from "./config";

const alchemy = new Alchemy(settings);

async function main_getBlock (blockHash: string)
{
    const result = await alchemy.core.send('eth_getBlockByHash', [blockHash, true]);

    const common = Common.custom(CustomChain.PolygonMainnet, {hardfork: 'london'});
    const b = Block.fromRPC(result, [], {common, skipConsensusFormatValidation: true});
    console.log('Height', b.header.number)

    console.log('RLP', hexlify(b.header.serialize()));
    assert(blockHash == hexlify(b.hash()));
    console.log('blockHash', hexlify(b.hash()), blockHash == hexlify(b.hash()));
}

function getMapSlot(holderAddress: string, mappingPosition: number): string {
    // Equivalent to keccak256(abi.encodePacked(bytes32(holder), mappingPosition));
    return solidityPackedKeccak256(
      ["bytes32", "uint256"],
      [zeroPadValue(holderAddress, 32), mappingPosition]
    )
  }

async function main_getStorageProof (blockHash: string, account: string, slots: {slot:number, key?:string}[])
{
    let slothashes: string[] = [];

    for( let s of slots )
    {
        if( s.key ) {
            const storageKey = getMapSlot(s.key, s.slot)
            slothashes.push(storageKey);
        }
        else {
            const pos = toBeHex(s.slot, 32);
            slothashes.push(pos);
        }
    }

    const result = await alchemy.core.send('eth_getProof', [
        account,
        slothashes,
        blockHash,
    ]);

    console.dir(result, {depth: null});

    return result;
}

async function main ()
{
    const blockHash = '0xcb6242f4219a09f7ef7dfd51f7594b23d2a6ad1e06b8b99a55fef4ec82cf61af';
    //await main_getBlock(blockHash);

    // Example to get the WMATIC token balance of an address at a specific height
    const wmatic_Contract = '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
    await main_getStorageProof(
        blockHash,
        wmatic_Contract,
        [{slot: 3, key: '0x6d80113e533a2c0fe82eabd35f1875dcea89ea97'}]);
}

Promise.all([main()]);
