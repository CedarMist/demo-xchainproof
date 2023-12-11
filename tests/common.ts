import { Common, CustomChain } from '@ethereumjs/common';
import { BlockHeader } from '@ethereumjs/block';
import { BytesLike, getBytes } from 'ethers';

export const ETHEREUMJS_COMMON = Common.custom(CustomChain.PolygonMainnet, {hardfork: 'london'});

export const ETHEREUMJS_BLOCK_OPTIONS = {common: ETHEREUMJS_COMMON, skipConsensusFormatValidation: true};

export function decodeBlockHeaderRlp(rlpData:BytesLike) {
    return BlockHeader.fromRLPSerializedHeader(getBytes(rlpData), ETHEREUMJS_BLOCK_OPTIONS);
}
