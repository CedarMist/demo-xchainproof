import { ethers } from 'hardhat';
import { expect } from 'chai';

import { Account } from '@ethereumjs/util';
import { decodeRlp, encodeRlp, zeroPadValue } from 'ethers';

import { AccountCache, HeaderCache, StorageProof } from "../typechain-types";
import { BLOCK_HEADERS, PROOFS } from './exampleproofs';
import { decodeBlockHeaderRlp } from "./common";

describe('On-chain proof-validating caches', () => {
    let hc : HeaderCache;
    let ac : AccountCache;
    let sp : StorageProof;

    before(async () => {
        const hcf = await ethers.getContractFactory('HeaderCache');
        hc = await hcf.deploy();

        const acf = await ethers.getContractFactory('AccountCache');
        ac = await acf.deploy(await hc.getAddress());

        const spf = await ethers.getContractFactory('StorageProof');
        sp = await spf.deploy(await ac.getAddress());
    });

    it('HeaderCache', async () => {
        // All of the hard-coded test blocks
        for( const [k,v] of Object.entries(BLOCK_HEADERS) )
        {
            // Contract must decode them properly
            const header = decodeBlockHeaderRlp(v);
            const headerJson = header.toJSON();
            const x = await hc.extractHeader(v);
            expect(x.transactionRoot).equals(headerJson.transactionsTrie);
            expect(x.stateRoot).equals(headerJson.stateRoot);
            expect(x.receiptsRoot).equals(headerJson.receiptTrie);
            expect(x.blockTimestamp).equals(headerJson.timestamp);

            // Can add them to the cache
            expect(await hc.exists(header.hash())).equals(false);
            await hc.add(v);
            expect(await hc.exists(header.hash())).equals(true);

            // And retrieve them correcty
            const y = await hc.get(k);
            expect(y.transactionRoot).equals(headerJson.transactionsTrie);
            expect(y.stateRoot).equals(headerJson.stateRoot);
            expect(y.receiptsRoot).equals(headerJson.receiptTrie);
            expect(y.blockTimestamp).equals(headerJson.timestamp);
        }
    });

    it('AccountCache', async () => {
        // All of the hard-coded account based proofs
        for( const x of PROOFS ) {
            const account = Account.fromAccountData(x.proof);
            const block = decodeBlockHeaderRlp(BLOCK_HEADERS[x.blockHash]);
            const accountProofNodesRlp = encodeRlp(x.proof.accountProof.map(decodeRlp));

            // Verify the account proof, returning the account data
            const p = await ac.verifyAccount(block.stateRoot, x.proof.address, accountProofNodesRlp);
            expect(p.nonce).equals(account.nonce);
            expect(p.balance).equals(account.balance);
            expect(p.storageRoot).equals(x.proof.storageHash);
            expect(p.codeHash).equals(x.proof.codeHash);

            // Adding it to the cache works
            if( ! await ac.exists(x.blockHash, x.proof.address) )
            {
                await ac.add(x.blockHash, x.proof.address, accountProofNodesRlp)
                expect(await ac.exists(x.blockHash, x.proof.address)).equals(true);
            }
        }
    });

    it('StorageProof', async () => {
        // For each of the proofs which have storage proofs
        for( const x of PROOFS )
        {
            if( 0 == x.proof.storageProof.length )
            {
                continue;
            }

            // Verify the proofs, account & block have been pre-cached
            for( const i in x.proof.storageProof )
            {
                const slot = x.slots[i];
                const storageProof = x.proof.storageProof[i];

                const storageProofNodesRlp = encodeRlp(storageProof.proof.map(decodeRlp));

                const r = await sp.verifyStorage(
                    x.blockHash,
                    x.proof.address,
                    slot.slot,
                    zeroPadValue(slot.key, 32),
                    storageProofNodesRlp);

                expect(r).equals(zeroPadValue(storageProof.value, 32))
            }
        }
    });
});
