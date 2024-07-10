// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

pragma solidity 0.8.26;

contract ExamPass is ERC721Enumerable, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint private student_id;
    uint private invigilator_id;

    struct Student {
        string matricNumber;
        string studentName;
        bool paid;
        bool registered;
        uint id;
        bool hasRequestedPass;
    }

    struct Invigilator {
        string name;
        string staffId;
        bool registered;
    }

    mapping(address => Student) students;
    mapping(address => Invigilator) invigilators;

    mapping(bytes32 => bool) registeredStudentHash;
    mapping(bytes32 => bool) registeredInvigilatorHash;

    mapping(bytes32 => address) private studentHashToAddress;
    mapping(bytes32 => address) private invigilatorHashToAddress;

    EnumerableSet.Bytes32Set private EligibleStudentHashes;
    EnumerableSet.Bytes32Set private EligibleInvigilatorHashes;

    uint private tokenId_counter;

    modifier onlyAdmin() {
        require(msg.sender == owner(), "Not Authorized");
        _;
    }

    modifier onlyRegisteredStudents() {
        require(students[msg.sender].registered == true, "Not Registered");
        _;
    }

    modifier onlyRegisteredInvigilators() {
        require(invigilators[msg.sender].registered == true, "Invigilator not registered");
        _;
    }

    constructor() ERC721("ExaminationPass", "EXAM") Ownable(msg.sender) {
        transferOwnership(msg.sender);
        student_id = 0;
        invigilator_id = 0;
    }

    event studentRegistered(address studentAddress, string studentName, string matricNumber, uint student_Id);
    event invigilatorRegistered(address invigilatorAddress, string _name, string _staffId);
    event examinationPassRequested(address studentAddress, uint tokenId);

    function registerStudent(string memory _studentName, string memory _matricNumber) external {
        bytes32 _hash = keccak256(abi.encodePacked(_studentName, _matricNumber));
        require(registeredStudentHash[_hash] == false, "Student has already registered");
        require(msg.sender != address(0), "Cannot register a zero address");
        require(msg.sender != owner(), "Admin cannot register as a student");
        require(students[msg.sender].registered == false, "Student already registered");
        require(EligibleStudentHashes.contains(_hash), "Invalid student credentials");
        require(studentHashToAddress[_hash] == address(0), "Student hash already managed by another address");

        students[msg.sender] = Student({
            matricNumber: _matricNumber,
            studentName: _studentName,
            paid: false,
            registered: true,
            id: student_id += 1,
            hasRequestedPass: false
        });

        registeredStudentHash[_hash] = true;
        studentHashToAddress[_hash] = msg.sender;

        emit studentRegistered(msg.sender, _studentName, _matricNumber, students[msg.sender].id);
    }

    function registerInvigilator(string memory _name, string memory _staffId) external {
        bytes32 _hash = keccak256(abi.encodePacked(_name, _staffId));
        require(registeredInvigilatorHash[_hash] == false, "Staff has already been enrolled");
        require(msg.sender != address(0), "Cannot register a zero address");
        require(msg.sender != owner(), "Admin cannot register as an invigilator");
        require(invigilators[msg.sender].registered == false, "Invigilator already registered");
        require(EligibleInvigilatorHashes.contains(_hash), "Invalid invigilator credentials");
        require(invigilatorHashToAddress[_hash] == address(0), "Invigilator hash already managed by another account");

        invigilators[msg.sender] = Invigilator({
            name: _name,
            staffId: _staffId,
            registered: true
        });

        registeredInvigilatorHash[_hash] = true;

        emit invigilatorRegistered(msg.sender, _name, invigilators[msg.sender].staffId);
    }

    function mintNFT(address to) internal returns (uint) {
        uint tokenId = tokenId_counter;
        tokenId_counter++;
        _safeMint(to, tokenId);

        return tokenId;
    }

    function requestExaminationPass() external onlyRegisteredStudents returns (uint) {
        require(students[msg.sender].paid == true, "Student has not paid the required fees");
        require(students[msg.sender].hasRequestedPass == false, "Student has already requested an examination pass");
        uint tokenId = mintNFT(msg.sender);
        students[msg.sender].hasRequestedPass = true;
        emit examinationPassRequested(msg.sender, tokenId);
        return tokenId;
    }

    function hasPaidFees(address studentAddress) external view onlyRegisteredStudents onlyAdmin returns (bool) {
        require(students[studentAddress].registered == true, "Student not registered");
        bytes32 _hash = keccak256(abi.encodePacked(students[studentAddress].studentName, students[studentAddress].matricNumber));
        require(studentHashToAddress[_hash] == studentAddress, "Student hash not managed by this address");

        return students[studentAddress].paid;
    }

    event studentMarkedPaid(address studentAddress);

    function markFeesAsPaid(address studentAddress) external onlyAdmin {
        require(students[studentAddress].registered == true, "Student not registered");
        require(students[studentAddress].paid == false, "Student has already been marked as paid");
        students[studentAddress].paid = true;
        emit studentMarkedPaid(studentAddress);
    }

    function verifyExaminationPass(uint tokenId) external view onlyRegisteredInvigilators returns (
        string memory name,
        string memory matricNumber,
        bool registrationStatus,
        bool paidStatus,
        uint examToken,
        uint UID) {
        require(tokenId < tokenId_counter && students[ownerOf(tokenId)].registered == true
            && students[ownerOf(tokenId)].paid == true, "Invalid Exam Token");
        return (
            students[ownerOf(tokenId)].studentName,
            students[ownerOf(tokenId)].matricNumber,
            students[ownerOf(tokenId)].registered,
            students[ownerOf(tokenId)].paid,
            tokenId,
            students[ownerOf(tokenId)].id
        );
    }

    function addStudentHash(string memory studentName, string memory studentMatric) external onlyAdmin {
        bytes32 _hash;
        _hash = keccak256(abi.encodePacked(studentName, studentMatric));
        require(!EligibleStudentHashes.contains(_hash), "Student Already Added");
        EligibleStudentHashes.add(_hash);
    }

    function addInvigilatorHash(string memory staffName, string memory staffId) external onlyAdmin {
        bytes32 _hash = keccak256(abi.encodePacked(staffName, staffId));
        require(!EligibleInvigilatorHashes.contains(_hash), "Invigilator Already Added");
        EligibleInvigilatorHashes.add(_hash);
    }

    function removeStudentHash(string memory studentName, string memory studentMatric) external onlyAdmin {
        bytes32 _hash = keccak256(abi.encodePacked(studentName, studentMatric));
        require(studentHashToAddress[_hash] != address(0), "Student hash not managed by any address");

        address studentAddress = studentHashToAddress[_hash];
        delete students[studentAddress];
        delete registeredStudentHash[_hash];
        delete studentHashToAddress[_hash];

        EligibleStudentHashes.remove(_hash);
    }

    function removeInvigilatorHash(string memory staffName, string memory staffId) external onlyAdmin {
        bytes32 _hash = keccak256(abi.encodePacked(staffName, staffId));
        require(invigilatorHashToAddress[_hash] != address(0), "Invigilator hash not managed by any address");
        address invigilatorAddress = invigilatorHashToAddress[_hash];
        delete invigilators[invigilatorAddress];
        delete registeredInvigilatorHash[_hash];
        delete invigilatorHashToAddress[_hash];
        EligibleInvigilatorHashes.remove(_hash);
    }

    function getStudentHashes() external view onlyAdmin returns (bytes32[] memory) {
        return EligibleStudentHashes.values();
    }

    function getInvigilatorHashes() external view onlyAdmin returns (bytes32[] memory) {
        return EligibleInvigilatorHashes.values();
    }

    function tokensOfOwner(address owner) public view returns (uint[] memory) {
        uint tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint[](0)  ;
        } else {
            uint[] memory result = new uint[](tokenCount);
            for (uint i = 0; i < tokenCount; i++) {
                result[i] = tokenOfOwnerByIndex(owner, i);
            }
            return result;
        }
    }
}
