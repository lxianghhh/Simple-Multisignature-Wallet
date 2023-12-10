// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Wallet{
    event Setup(address indexed initiator, address[] owners, uint256 threshold);

    event ExecutionSuccess(bytes32 indexed txhash);
    event ExecutionFailure(bytes32 indexed txhash);

    event AddOwner(address indexed owner);
    event RemoveOwner(address indexed preowner);
    event ChangeThreshold(uint256 threshold);

    event Receiveeth(uint256 value);
    event Callfallback(uint256 value, bytes data);

    // 设置改变钱包持有人参数的权限，必须要此钱包发动交易才可以改变参数
    modifier signed{
        require(msg.sender==address(this),"Not authorized");
        _;
    }

    // 钱包拥有者数组
    address[] internal owners;
    // 钱包拥有者记录
    mapping (address=>bool) internal isowners;
    // 钱包拥有者人数
    uint256 internal owners_num;
    // 执行交易的门槛
    uint256 internal threshold;
    // 交易次数
    uint256 public nonce;
    constructor(
        address[] memory _owners,
        uint256 _threshold
    ){
        _initialwallet(_owners, _threshold);
    }

    function _initialwallet(address[] memory _owners,uint256 _threshold)internal {
        // 确认钱包之前未被初始化
        require(threshold == 0, "error01");
        // 确认交易门槛小于多签人数
        require(_threshold <= _owners.length, "error02");
        // 确认交易门槛大于1
        require(_threshold >= 1, "error03");
        // 记录多签持有人
        for (uint i=0; i<_owners.length;i++)
        {
            address owner = _owners[i];
            // 多签人不能为0地址，本合约地址，不能重复
            require(owner != address(0) && owner != address(this) && !isowners[owner],"error04");
            owners.push(owner);
            isowners[owner]=true;
        }
        threshold = _threshold;
        owners_num = owners.length;
        emit Setup(msg.sender, owners, threshold);
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
            require(currentowner != lastowner && isowners[currentowner], "error06");
            //currentowner > lastowner && 
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
        // return keccak256();
        
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

    // 增加钱包持有人并改变交易门槛
    // 此函数不可直接调用，需间接调用
    function addOwnersAndThreshold(address new_owner, uint256 new_threshold)public signed{
        // 检查门槛设置是否合法
        require(owners_num + 1 >= new_threshold && new_threshold >= 0);
        // 验证增加的持有人地址是否合法
        require(new_owner != address(0) && new_owner != address(this) && !isowners[new_owner],"error04");        
        owners.push(new_owner);
        owners_num++;
        isowners[new_owner] =true;
        emit AddOwner(new_owner);
        // 检查新设置的交易门槛是否与原先一致
        if (new_threshold != threshold) changeThreshold(new_threshold);
    }

    // 删除钱包持有人
    // 此函数不可直接调用，需间接调用
    function removeOwners(address preowner, uint256 new_threshold)public signed{
        // 检查门槛设置是否合法
        require(owners_num - 1 >=new_threshold,"error02");
        // 检查持有人是否存在
        require(isowners[preowner],"error07");
        // 删除持有人
        isowners[preowner] = false;
        for (uint256 i=0; i<owners.length; i++){
            if (owners[i] == preowner){
                owners[i] = address(0);
                break;
            }
        }
        owners_num--;
        emit RemoveOwner(preowner);
        if(new_threshold != threshold) changeThreshold(new_threshold);
    }

    // 改变交易门槛
    // 此函数不可直接调用，需间接调用
    function changeThreshold(uint256 new_threshold)public signed{
        // 确认交易门槛小于多签人数
        require(new_threshold <= owners_num, "error02");
        // 确认交易门槛大于1
        require(new_threshold >= 1, "error03");
        threshold = new_threshold;
        emit ChangeThreshold(threshold);
    }

    // 查看交易门槛
    function checkThreshold()public view  returns(uint256){
        return threshold;
    } 
    
    // 查看钱包持有人
    function checkOwners()public view returns(address[] memory){
        address[] memory array = new address[](owners_num);
        uint256 index = 0;
        for(uint256 i =0; i<owners.length; i++){
            if (isowners[owners[i]]){
                array[index] = owners[i];
                index++;
            }
        }
        return array;
    }
    // 判断钱包持有人
    function isOwner(address addr)public view returns(bool) {
        return isowners[addr];
    }

    receive() external payable {
        emit Receiveeth(msg.value);
    }

    fallback() external payable {
        emit Callfallback(msg.value, msg.data);
    }

    // 获取改交易门槛函数的abi
    function changeThresholdencode(uint256 x) public pure returns(bytes memory result) {
        result =abi.encodeWithSelector(bytes4(keccak256("changeThreshold(uint256)")), x);
        return result;
    }
    // 获取增加持有人函数的abi
    function addOwnersencode(address x, uint256 y) public pure returns(bytes memory result) {
        result =abi.encodeWithSelector(bytes4(keccak256("addOwnersAndThreshold(address,uint256)")),x,y);
        return result;
    }
    // 获取减少交易门槛函数的abi
    function removeOwnersencode(address x, uint256 y) public pure returns(bytes memory result) {
        result =abi.encodeWithSelector(bytes4(keccak256("removeOwners(address,uint256)")), x,y);
        return result;
    }

}