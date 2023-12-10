// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Manageowner{
    event AddOwner(address indexed owner);
    event RemoveOwner(address indexed preowner);
    event ChangeThreshold(uint256 threshold);

    // 钱包拥有者人数
    uint256 public owners_num;
    // 执行交易的门槛
    uint256 internal threshold;
    // 钱包拥有者链表
    mapping (address=>mapping(bool=>address)) internal owners;
    // 用true和false表示方向
    bool internal constant _PRE = false;
    bool internal constant _NEXT = true;
    // 初始化空地址和默认首地址
    address internal constant _NULL = address(0);
    address internal constant _HEAD = address(0x1);

    function _initialwallet(address[] memory _owners,uint256 _threshold)internal {
        // 确认钱包之前未被初始化
        require(threshold == 0, "error01");
        // 确认交易门槛小于多签人数
        require(_threshold <= _owners.length, "error02");
        // 确认交易门槛大于1
        require(_threshold >= 1, "error03");
        // 记录多签持有人
        address currentowner = _HEAD;
        for (uint i=0; i<_owners.length;i++)
        {
            address owner = _owners[i];
            // 多签人不能为0地址，本合约地址，不能重复
            require(owner != address(0) && owner != address(this) && !ownerExist(owner),"error04");
            addowner(owner);
            currentowner = owner;
        }
        // 记录相关参数
        threshold = _threshold;
        owners_num = _owners.length;
        
    }

    // 增加钱包持有人
    // 此函数不可直接调用，需间接调用
    function addOwnersAndThreshold(address owner, uint256 new_threshold)public signed{
        // 检查门槛设置是否合法
        require(owners_num + 1 >= new_threshold && new_threshold >= 0);
        // 验证增加的持有人地址是否合法
        require(owner != address(0) && owner != address(this) && !ownerExist(owner),"error04");        
        addowner(owner);
        emit AddOwner(owner);
        // 检查新设置的交易门槛是否与原先一致
        if (new_threshold != threshold) changeThreshold(new_threshold);
    }

    // 删除钱包持有人
    // 此函数不可直接调用，需间接调用
    function removeOwners(address preowner, uint256 new_threshold)public signed{
        // 检查门槛设置是否合法
        require(owners_num - 1 >=new_threshold,"error02");
        // 检查持有人是否存在
        require(ownerExist(preowner),"error07");
        // 删除持有人
        removeowner(preowner);
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
    function checkThreshold()public view returns(uint256){
        return threshold;
    } 

    // 查看钱包持有人
    function checkOwners()public view returns(address[] memory){
        address[] memory array = new address[](owners_num);
        address currentowner = owners[_HEAD][_NEXT];
        uint256 index = 0;
        for (index=0; index < owners_num; index++){
            array[index] = currentowner;
            (,currentowner) = getAdjacent(currentowner,_NEXT);
        }
        return array;
    }

    // 增加钱包持有人
    function addowner(address owner)private {
        require(owner != address(0) && owner != address(this) && !ownerExist(owner),"error04");
        address currentowner = _HEAD;
        address nextowner;
        (,nextowner) = getAdjacent(currentowner,_NEXT);
        while (nextowner != _NULL){
                if (nextowner > owner && currentowner < owner){
                    _insert(currentowner, owner, _NEXT);
                    break;
                }
                else {
                    if (nextowner > owner){
                        nextowner = currentowner;
                        (,currentowner) = getAdjacent(currentowner, _PRE);
                    }
                    else{
                        currentowner = nextowner;
                        (,nextowner) = getAdjacent(nextowner, _NEXT);
                    }
                }
            }
        if (nextowner == _NULL) _insert(currentowner, owner, _NEXT);
        owners_num++;
    }

    // 移除钱包持有人
    function removeowner(address preowner)internal {
        require(ownerExist(preowner),"error07");
        _createLink(owners[preowner][_PRE], owners[preowner][_NEXT], _NEXT);
        delete owners[preowner][_PRE];
        delete owners[preowner][_NEXT];
        owners_num--;
    }
    
    // 插入链表节点
    function _insert( address _owner, address _newowner, bool _direction)internal {
        
        address c = owners[_owner][_direction];
        _createLink(_owner, _newowner, _direction);
        _createLink(_newowner, c, _direction);

    }
    // 判断地址是否为多签持有人
    function ownerExist(address _owner)public view returns (bool){
        return (owners[_owner][_PRE] != _NULL || owners[_owner][_NEXT] != _NULL); 
    }
    // 初始化节点
    function _createLink(address _preowner, address _nextowner, bool _direction)internal {
        owners[_nextowner][!_direction] = _preowner;
        owners[_preowner][_direction] = _nextowner;
    }
    // 查看下一个节点
    function getAdjacent(address owner, bool _direction)internal view returns (bool, address) {
        if (!ownerExist(owner)) {
            return (false, _NULL);
        } else {
            return (true, owners[owner][_direction]);
        }
    }

    // 设置改变钱包持有人参数的权限，必须要此钱包发动交易才可以改变参数
    modifier signed{
        require(msg.sender==address(this),"Not authorized");
        _;
    }

    // 获取改交易门槛函数的abi
    function changeThresholdencode(uint256 new_threshold) public pure returns(bytes memory result) {
        result =abi.encodeWithSelector(bytes4(keccak256("changeThreshold(uint256)")), new_threshold);
    }
    // 获取增加持有人函数的abi
    function addOwnersencode(address x, uint256 y) public pure returns(bytes memory result) {
        result =abi.encodeWithSelector(bytes4(keccak256("addOwnersAndThreshold(address,uint256)")),x,y);
    }

    // 获取减少持有人函数的abi
    function removeOwnersencode(address x, uint256 y) public pure returns(bytes memory result) {
        result =abi.encodeWithSelector(bytes4(keccak256("removeOwners(address,uint256)")), x,y);
        return result;
    }

}