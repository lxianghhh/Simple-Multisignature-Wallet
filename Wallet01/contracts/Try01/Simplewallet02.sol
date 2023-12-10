// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import{Manageowner} from "./Manage.sol";

contract Wallet is Manageowner{

    event ExecutionSuccess(bytes32 indexed txhash);
    event ExecutionFailure(bytes32 indexed txhash);

    event Receiveeth(uint256 value);
    event Callfallback(uint256 value, bytes data);
    
    // 交易次数
    uint256 public nonce;
    constructor(
        address[] memory _owners,
        uint256 _threshold
    ){
        _initialwallet(_owners, _threshold);
    }

    // 创建并执行交易
    function exertransact(
        // 转入的地址
        address to,
        // 转账金额
        uint256 value,
        // 附带信息
        bytes calldata data,
        // 签名
        bytes memory signatures
        )public payable virtual returns(bool success){
            bytes32 txhash;
            // 获取交易哈希
            txhash = encodetx(
                to,
                value, 
                data,
                nonce,
                block.chainid
                );
            nonce++;
            // 检查签名
            checkSignature(txhash, signatures);
            // 验证通过则开始交易
            (success,) = to.call{value: value}(data);
            if (success)
                emit ExecutionSuccess(txhash);
            else 
                emit ExecutionFailure(txhash);                
        }
    // 验证签名
    function checkSignature(bytes32 datatxhash, bytes memory signatures)public view {
        uint256 _threshold = threshold;
        // 检查门槛是否设定
        require(_threshold > 0, "error05");
        // 开始验证签名
        startCheckSignature(datatxhash, signatures, _threshold);
    }
    function startCheckSignature (bytes32 txhash, bytes memory signatures, uint256 numOfsignatures)internal view {
        // 检查签名足够长
        require(signatures.length >= numOfsignatures * 65,"Signatures too short");
        // 开始循环检查签名
        // 1. 用ecdsa先验证签名是否有效
        // 2. 利用 currentOwner > lastOwner 确定签名来自不同多签（多签地址递增）
        // 3. 利用 isOwner[currentOwner] 确定签名者为多签持有人
        address lastowner;
        address currentowner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for(i=0; i<numOfsignatures; i++){
            (v, r, s) = signatureSplit(signatures, i);
            // 验证签名是否有效,ecrecover()函数获取交易哈希与签名，返回公钥(地址)
            currentowner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",txhash)), v, r, s);
            require(currentowner > lastowner && ownerExist(currentowner), "error06");
            
            lastowner = currentowner;
        }
    }
    // 将单个签名从打包的签名分离出来
    
    function signatureSplit(bytes memory signatures, uint256 pos)internal pure returns(uint8 v,bytes32 r,bytes32 s){
        // 签名的格式：{bytes32 r}{bytes32 s}{uint8 v}
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }

    // 获取交易信息
    function getTxhash(
        address to,
        uint256 value,
        bytes memory data
    ) public view returns(bytes32) {
        return encodetx(to,value,data,nonce,block.chainid);
    }

    //编码交易信息
    function encodetx(
        address to,
        uint256 value,
        bytes memory data,
        uint256 _nonce,
        uint256 chainid
    )private pure returns(bytes32){
        bytes32 safetxhash = keccak256(
            abi.encode(
                to,
                value,
                keccak256(data),
                _nonce,
                chainid
            )
        );
        return safetxhash;
    }
    

    receive() external payable {
        emit Receiveeth(msg.value);
    }

    fallback() external payable {
        emit Callfallback(msg.value, msg.data);
    }

    

}