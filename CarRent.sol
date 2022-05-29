// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.0;

contract CarRent {
    address payable public owner;

    uint public countCar = 0;
    uint public countRentAgreement = 0;
    uint totalFund = 0;

    enum CarStatus {AVAILABLE, NOT_AVAILABLE}
    enum CarType {HATCHBACK, MPV, SUV}

    constructor() {
        owner = msg.sender;
    }

    struct Car {
        uint carId;
        string carName;
        string carBrand;
        CarType carType;
        uint rentFee;
        uint depositFee;
        uint penaltyFee;
        CarStatus carStatus;
        uint currentRentAgreementId;
        address payable currentRenter;
    }
    mapping(uint => Car) public Cars;

    struct RentAgreement {
        uint rentAgreementId;
        uint carId;
        address payable carRenter;
        uint timestamp;
        uint rentPeriod;
        bool isGetPenalty;
        bool isAgreementCompleted;
    }
    mapping(uint => RentAgreement) public RentAgreements;

    modifier isOwner {
        require (owner == msg.sender, "You are not owner");
        _;
    }

    modifier isNotOwner {
        require (owner != msg.sender, "You are not renter");
        _;
    }

    modifier isCarAvailable(uint _carId) {
        require(Cars[_carId].carStatus == CarStatus.AVAILABLE, "The car is not available");
        _;
    }

    modifier rentFeeCheck(uint _carId, uint _rentPeriod) {
        uint totalFee = (Cars[_carId].depositFee + (Cars[_carId].rentFee * _rentPeriod)) * 1 ether;
        require(msg.value == totalFee, "Your payment is not fit with rent fee");
        _;
    }

    function addCar(string memory _carName, string memory _carBrand, CarType _carType, uint _rentFee, uint _depositFee, uint _penaltyFee) external isOwner {
        countCar++;
        Cars[countCar] = Car(countCar, _carName, _carBrand, _carType, _rentFee, _depositFee, _penaltyFee, CarStatus.AVAILABLE, 0, address(0));
    }

    event eventRentCar(uint _carId, address _carRenter, uint _rentFee);

    function rentCar(uint _carId, uint _rentPeriod) external payable isNotOwner isCarAvailable(_carId) rentFeeCheck(_carId, _rentPeriod) {
        // create rent agreement
        countRentAgreement++;
        RentAgreements[countRentAgreement] = RentAgreement(countRentAgreement, _carId, msg.sender, block.timestamp, _rentPeriod, false, false);

        // update car data
        Cars[_carId].carStatus = CarStatus.NOT_AVAILABLE;
        Cars[_carId].currentRentAgreementId = countRentAgreement;
        Cars[_carId].currentRenter = msg.sender;

        totalFund += msg.value;

        emit eventRentCar(_carId, msg.sender, msg.value);
    }

    event eventReturnCar(uint _carId, address _carRenter, bool isGetPenalty, uint returnDeposit);

    function returnCar(uint _carId) external payable isOwner {
        Car memory car = Cars[_carId];
        uint currentRentAgreementId = car.currentRentAgreementId;
        RentAgreement memory agreement = RentAgreements[currentRentAgreementId];

        // return deposit
        uint totalFee = agreement.rentPeriod * car.rentFee * 1 ether;
        uint returnDeposit = car.depositFee * 1 ether;
        // uint dueDate = agreement.timestamp + (agreement.rentPeriod * 1 days);
        uint dueDate = agreement.timestamp + (agreement.rentPeriod * 1 minutes);
        bool isGetPenalty = false;
        if (block.timestamp > dueDate) {
            isGetPenalty = true;
            totalFee += car.penaltyFee * 1 ether;
            returnDeposit -= car.penaltyFee * 1 ether;
        }

         // set flag agreement status
        RentAgreements[currentRentAgreementId].isGetPenalty = isGetPenalty;
        RentAgreements[currentRentAgreementId].isAgreementCompleted = true;

        // reset car data
        Cars[_carId].carStatus = CarStatus.AVAILABLE;
        Cars[_carId].currentRentAgreementId = 0;
        Cars[_carId].currentRenter = address(0);

        address payable renter = car.currentRenter;
        renter.transfer(returnDeposit);
        owner.transfer(totalFee);
        totalFund -= (totalFee + returnDeposit);

        emit eventReturnCar(_carId, renter, isGetPenalty, returnDeposit);
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }
}