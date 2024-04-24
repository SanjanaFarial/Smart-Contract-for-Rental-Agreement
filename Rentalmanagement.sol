// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RentalDepositManager {
    // State variables
    address payable public landlord;
    address payable public tenant;
    uint256 public rentalEndDate;
    uint256 public depositAmount;
    bool public dispute;
    bool public tenantFavored; // Indicates the outcome of the dispute
    enum AgreementState { Active, Completed }
    AgreementState public state;

    // Events
    event AgreementCreated(address landlord, address tenant, uint256 deposit, uint256 endDate);
    event DepositPaid(address tenant, uint256 amount);
    event Withdrawal(address to, uint256 amount);
    event DisputeInitiated();
    event DisputeResolved(bool tenantFavored);
    event AgreementCompleted();

    // Modifiers
    modifier onlyLandlord() {
        require(msg.sender == landlord, "Caller is not the landlord");
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Caller is not the tenant");
        _;
    }

    modifier rentalPeriodEnded() {
        require(block.timestamp >= rentalEndDate, "Rental period has not ended");
        _;
    }

    modifier inState(AgreementState _state) {
        require(state == _state, "Contract is not in the correct state");
        _;
    }

    // Constructor
    constructor(
        address payable _landlord,
        address payable _tenant,
        uint256 _depositAmount,
        uint256 _rentalEndDate
    ) {
        landlord = _landlord;
        tenant = _tenant;
        depositAmount = _depositAmount;
        rentalEndDate = _rentalEndDate;
        state = AgreementState.Active;
        emit AgreementCreated(landlord, tenant, depositAmount, rentalEndDate);
    }

    // Functions
    function payDeposit() external payable onlyTenant inState(AgreementState.Active) {
        require(msg.value == depositAmount, "Incorrect deposit amount");
        emit DepositPaid(tenant, msg.value);
    }

    function initiateDispute() external inState(AgreementState.Active) {
        require(msg.sender == landlord || msg.sender == tenant, "Only landlord or tenant can initiate a dispute");
        dispute = true;
        emit DisputeInitiated();
    }

    function resolveDispute(bool _tenantFavored) external onlyLandlord {
        require(dispute, "No dispute to resolve");
        tenantFavored = _tenantFavored;
        dispute = false;
        emit DisputeResolved(tenantFavored);
    }

    function completeAgreement() external onlyLandlord rentalPeriodEnded {
        require(state == AgreementState.Active, "Agreement is already completed");
        state = AgreementState.Completed;
        emit AgreementCompleted();
    }

    function withdrawDeposit() external inState(AgreementState.Completed) {
        if(dispute) {
            // If there was a dispute
            require((tenantFavored && msg.sender == tenant) || (!tenantFavored && msg.sender == landlord), "Not authorized to withdraw");
        } else {
            // If there was no dispute
            require(msg.sender == tenant, "Only tenant can withdraw without a dispute");
        }
        
        uint256 amountToWithdraw = address(this).balance;
        (bool sent, ) = msg.sender.call{value: amountToWithdraw}("");
        require(sent, "Failed to send Ether");
        emit Withdrawal(msg.sender, amountToWithdraw);
    }

    // Allow the contract to receive Ether
    receive() external payable {}

    // Public view functions to read contract details
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getAgreementDetails() public view returns (
        address, address, uint256, uint256, AgreementState, bool, bool
    ) {
        return (landlord, tenant, depositAmount, rentalEndDate, state, dispute, tenantFavored);
    }
}