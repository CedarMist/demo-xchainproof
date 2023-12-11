import { expect } from 'chai';
import { Account } from '@ethereumjs/util';
import { Trie } from '@ethereumjs/trie';
import { decodeBlockHeaderRlp }  from './common';
import { BLOCK_HEADERS, PROOFS } from './exampleproofs';
import { decodeRlp, encodeRlp, getBytes, hexlify } from 'ethers';

describe('Proofs', function () {
    it('Decode Block Headers', async () => {
        for( let [k,v] of Object.entries(BLOCK_HEADERS) ) {
            // Lets make sure all the hard-coded block headers can decode
            const header = decodeBlockHeaderRlp(v);
            expect(header.number).gt(0);
            expect(hexlify(header.hash())).equals(k);
        }
    });

    it('Example Proofs Verify', async () => {
        for( const x of PROOFS ) {
            const account = Account.fromAccountData(x.proof);
            const block = decodeBlockHeaderRlp(BLOCK_HEADERS[x.blockHash]);

            const accountProofNodesRlp = encodeRlp(x.proof.accountProof.map(decodeRlp));
            //const result = await t.verifyProof(block.stateRoot, account.serialize(), x.proof.accountProof.map((_) => getBytes(_)))
            //console.log(result);
        }
    });
});
