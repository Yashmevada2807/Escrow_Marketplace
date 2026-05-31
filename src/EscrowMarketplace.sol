// SPDX-License-Identifier:MIT

pragma solidity ^0.8.28;

contract EscrowMarketPlace {
    // errors
    error Unauthorized();
    error InsufficientBalance();
    error OnlyAccessByArbitor();
    error ArbitratorExist(address arbitratorAddress);
    error deliveryBoyExist();
    error OnlyAccessByDeliveryBoy();
    error InvalidQuantity();
    error OutOfStock();
    error ProductNotExist();
    error AlreadyDelivered();
    error AlreadyShipped();
    error AlreadyPaidToSeller();
    error NotShippedYet();
    error InvalidId();
    error invalidOTP();
    error AlreadyOpen();
    error AlreadyResolveOrEmpty();
    error CannotOpenDispute();
    error NoDisputeOnThisOrder();
    error CooldownPeriodActive();
    error NoFundsToWithdraw();
    error transactionFailed();

    // global variables
    address private immutable i_owner;
    uint256 public productCount;
    uint256 public orderCount;

    // enums
    enum Dispute_Status {
        NONE,
        OPEN,
        RESOLVED_TO_BUYER,
        RESOLVED_TO_SELLER
    }

    // structs

    struct Product {
        address productOwner;
        uint256 id;
        uint256 quantity;
        uint256 priceInWei;
        string name;
        bool inStock;
    }

    struct PurchaseOrder {
        address buyer;
        address seller;
        uint256 orderId;
        uint256 productId;
        uint256 quantity;
        uint256 totalBillInWei;
    }

    struct OrderShippingStatus {
        uint256 shippingTime;
        bool status;
        bool delivered;
    }

    struct OrderDeliveryStatus {
        uint256 deliveryTime;
        bool status;
    }

    struct DisputeStatus {
        uint256 orderId;
        uint256 disputeTime;
        Dispute_Status disputeStatus;
    }

    // mappings
    mapping(address => uint256) public buyerRefundedAmount;
    mapping(uint256 => Product) public products;
    mapping(uint256 => PurchaseOrder) public orders;
    mapping(address => bool) public arbitrators;
    mapping(address => bool) public deliveryBoys;
    mapping(address => uint256) public sellerEarnings;
    mapping(address => uint256) public arbitratorEarnings;
    mapping(address => uint256) public ownerEarnings;
    mapping(uint256 => OrderShippingStatus) public orderShippingStatus;
    mapping(uint256 => OrderDeliveryStatus) public orderDeliveryStatus;
    mapping(uint256 => DisputeStatus) public openDisputeStatus;

    // constructor
    constructor() {
        i_owner = msg.sender;
    }

    // modifiers
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert Unauthorized();
        _;
    }

    modifier onlyArbitrator() {
        if (!arbitrators[msg.sender]) revert OnlyAccessByArbitor();
        _;
    }

    modifier onlyBuyer(uint256 _orderId) {
        if (_orderId == 0 || _orderId > orderCount) revert InvalidId();
        if (orders[_orderId].buyer != msg.sender) revert Unauthorized();
        _;
    }

    modifier onlySeller(uint256 _orderId) {
        if (_orderId == 0 || _orderId > orderCount) revert InvalidId();
        uint256 prodId = orders[_orderId].productId;
        if (products[prodId].productOwner != msg.sender) revert Unauthorized();
        _;
    }

    modifier onlyDeliveryBoy(uint256 _orderId) {
        if (_orderId == 0 || _orderId > orderCount) revert InvalidId();
        if (!deliveryBoys[msg.sender]) revert OnlyAccessByDeliveryBoy();
        _;
    }

    // events
    event ArbitratorAdded(address indexed arbitorAddress);
    event DeliveryBoyAssigned(address indexed deliveryBoyAddress);
    event ProductAdded(address indexed prodOwner, uint256 indexed productId, uint256 quantity, uint256 price);
    event OrderDetail(
        uint256 indexed orderId, address indexed buyer, address indexed seller, uint256 quantity, uint256 totalPrice
    );
    event OrderShipped(uint256 indexed orderId, uint256 shippingTime, bool status);
    event OrderDelivered(uint256 indexed orderId, uint256 deliveryTime, bool status);
    event OrderDeliveredByDeliveryBoy(uint256 orderId, uint256 time, bool delivered);
    event DisputeAdded(uint256 indexed orderId, uint256 time, Dispute_Status state);

    event WithdrawalDone(address indexed withdrawalAddress, uint256 amount, uint256 time);

    // functions
    function addArbitrator(address _newArbitratorAdd) external onlyOwner {
        if (arbitrators[_newArbitratorAdd]) {
            revert ArbitratorExist(_newArbitratorAdd);
        }
        arbitrators[_newArbitratorAdd] = true;
        emit ArbitratorAdded(_newArbitratorAdd);
    }

    function addDeliverBoy(address _newDeliveryBoyAdd) external onlyOwner {
        if (deliveryBoys[_newDeliveryBoyAdd]) revert deliveryBoyExist();
        deliveryBoys[_newDeliveryBoyAdd] = true;
        emit DeliveryBoyAssigned(_newDeliveryBoyAdd);
    }

    function addProducts(uint256 _quantity, uint256 _priceInWei, string memory _name) external {
        if (_quantity == 0) revert InvalidQuantity();
        ++productCount;
        products[productCount] = Product({
            productOwner: msg.sender,
            id: productCount,
            quantity: _quantity,
            priceInWei: _priceInWei,
            name: _name,
            inStock: true
        });

        emit ProductAdded(msg.sender, productCount, _quantity, _priceInWei);
    }

    function buyProduct(uint256 _id, uint256 _quantity) external payable {
        Product storage product = products[_id];
        if (!product.inStock) revert ProductNotExist();
        if (_quantity == 0) revert InvalidQuantity();
        if (_quantity > product.quantity) revert OutOfStock();
        // basis-point-system:- 6% platformfee
        uint256 platformCutoff = 600;
        uint256 totalCost = product.priceInWei * _quantity;
        // eg:- (10ETH * 600)/ 10000 = 0.4 ETH
        uint256 platformCharge = (totalCost * platformCutoff) / 10000;
        // eg:- 10ETH + 0.6ETH = 10.6 ETH
        uint256 finalPayment = totalCost + platformCharge;
        if (msg.value != finalPayment) revert InsufficientBalance();

        product.quantity -= _quantity;
        if (product.quantity == 0) product.inStock = false;
        ownerEarnings[i_owner] += platformCharge;
        ++orderCount;

        orders[orderCount] = PurchaseOrder({
            buyer: msg.sender,
            seller: product.productOwner,
            orderId: orderCount,
            productId: _id,
            quantity: _quantity,
            totalBillInWei: finalPayment
        });

        emit OrderDetail(orderCount, msg.sender, product.productOwner, _quantity, totalCost);
    }

    function confirmShipping(uint256 _orderId) external onlySeller(_orderId) {
        OrderShippingStatus storage shippingStatus = orderShippingStatus[_orderId];
        if (shippingStatus.status) revert AlreadyShipped();
        shippingStatus.shippingTime = block.timestamp;
        shippingStatus.status = true;
        shippingStatus.delivered = false;
        emit OrderShipped(_orderId, block.timestamp, true);
    }

    function confirmDelivery(uint256 _orderId) external onlyBuyer(_orderId) {
        OrderDeliveryStatus storage deliveryStatus = orderDeliveryStatus[_orderId];
        OrderShippingStatus storage shippingStatus = orderShippingStatus[_orderId];
        if (!shippingStatus.status) revert NotShippedYet();
        if (deliveryStatus.status) revert AlreadyDelivered();
        deliveryStatus.deliveryTime = block.timestamp;
        deliveryStatus.status = true;
        emit OrderDelivered(_orderId, block.timestamp, true);
    }

    function confirmDeliveryByDeliveryBoy(uint256 _orderId) external onlyDeliveryBoy(_orderId) {
        OrderDeliveryStatus storage deliveryStatus = orderDeliveryStatus[_orderId];
        OrderShippingStatus storage shippingStatus = orderShippingStatus[_orderId];
        if (!shippingStatus.status) revert NotShippedYet();
        if (!deliveryStatus.status) revert invalidOTP();
        uint256 amount = orders[_orderId].totalBillInWei;
        if (amount == 0) revert AlreadyPaidToSeller();
        address sellerAddress = orders[_orderId].seller;
        uint256 productChargeCutOff = 1000;
        uint256 finalCutoff = (amount * productChargeCutOff) / 10000;
        uint256 finalPayment = amount - finalCutoff;
        orders[_orderId].totalBillInWei = 0;
        shippingStatus.delivered = true;
        sellerEarnings[sellerAddress] += finalPayment;

        emit OrderDeliveredByDeliveryBoy(_orderId, block.timestamp, true);
    }

    function checkDeliveryStatusOfProduct(uint256 _orderId)
        external
        view
        onlyArbitrator
        returns (bool shippingStatus, bool deliveryStatus, bool isDeliveredByDeliverBoy)
    {
        if (_orderId == 0 || _orderId > orderCount) revert InvalidId();
        shippingStatus = orderShippingStatus[_orderId].status;
        deliveryStatus = orderDeliveryStatus[_orderId].status;
        isDeliveredByDeliverBoy = orderShippingStatus[_orderId].delivered;
    }

    function openDispute(uint256 _orderId) external onlyBuyer(_orderId) {
        OrderShippingStatus storage shippingStatus = orderShippingStatus[_orderId];
        DisputeStatus storage disputeStatus = openDisputeStatus[_orderId];
        if (shippingStatus.delivered) revert AlreadyDelivered();
        if (block.timestamp < shippingStatus.shippingTime + 5 minutes) {
            revert CannotOpenDispute();
        }
        if (disputeStatus.disputeStatus == Dispute_Status.OPEN) {
            revert AlreadyOpen();
        }
        disputeStatus.orderId = _orderId;
        disputeStatus.disputeStatus = Dispute_Status.OPEN;
        disputeStatus.disputeTime = block.timestamp;

        emit DisputeAdded(_orderId, block.timestamp, Dispute_Status.OPEN);
    }

    function resolveDispute(uint256 _orderId, bool _confirmDeliveryStatusFromDeliveryService) external onlyArbitrator {
        if (_orderId == 0 || _orderId > orderCount) revert InvalidId();
        DisputeStatus storage disputeStatus = openDisputeStatus[_orderId];
        if (disputeStatus.disputeStatus == Dispute_Status.NONE) {
            revert NoDisputeOnThisOrder();
        }
        if (block.timestamp < disputeStatus.disputeTime + 5 minutes) {
            revert CooldownPeriodActive();
        }

        uint256 amount = orders[_orderId].totalBillInWei;
        if (amount == 0) revert AlreadyResolveOrEmpty();

        orders[_orderId].totalBillInWei = 0;
        uint256 arbitratorCutOff = 400;
        uint256 arbitratorPercentage = (amount * arbitratorCutOff) / 10000;
        uint256 platformCutOff = 600;
        uint256 platformPercentage = (amount * platformCutOff) / 10000;

        if (_confirmDeliveryStatusFromDeliveryService) {
            // give money to seller after cutting some percentage
            disputeStatus.disputeStatus = Dispute_Status.RESOLVED_TO_SELLER;
            address sellerAddress = orders[_orderId].seller;
            uint256 productChargeCutOff = 1000;
            uint256 finalCutoff = (amount * productChargeCutOff) / 10000;
            uint256 sellerFinaleEarnings = amount - finalCutoff - arbitratorPercentage;
            sellerEarnings[sellerAddress] += sellerFinaleEarnings;
            arbitratorEarnings[msg.sender] += arbitratorPercentage;
            ownerEarnings[i_owner] += finalCutoff;
        } else {
            // return back money to buyer
            disputeStatus.disputeStatus = Dispute_Status.RESOLVED_TO_BUYER;
            address buyerAddress = orders[_orderId].buyer;
            uint256 refundAmount = amount - platformPercentage - arbitratorPercentage;
            buyerRefundedAmount[buyerAddress] += refundAmount;
            arbitratorEarnings[msg.sender] += arbitratorPercentage;
        }
    }

    function withdrawAmount() external {
        uint256 totalAmountWithdraw = 0;

        if (buyerRefundedAmount[msg.sender] > 0) {
            totalAmountWithdraw += buyerRefundedAmount[msg.sender];
            buyerRefundedAmount[msg.sender] = 0;
        }

        if (sellerEarnings[msg.sender] > 0) {
            totalAmountWithdraw += sellerEarnings[msg.sender];
            sellerEarnings[msg.sender] = 0;
        }

        if (arbitrators[msg.sender] && arbitratorEarnings[msg.sender] > 0) {
            totalAmountWithdraw += arbitratorEarnings[msg.sender];
            arbitratorEarnings[msg.sender] = 0;
        }

        if (msg.sender == i_owner && ownerEarnings[msg.sender] > 0) {
            totalAmountWithdraw += ownerEarnings[msg.sender];
            ownerEarnings[msg.sender] = 0;
        }

        if (totalAmountWithdraw == 0) revert NoFundsToWithdraw();

        (bool success,) = payable(msg.sender).call{value: totalAmountWithdraw}("");

        if (!success) revert transactionFailed();
        emit WithdrawalDone(msg.sender, totalAmountWithdraw, block.timestamp);
    }
}
