// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract timelocked{
    bool internal locked;
    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    //shows the deposited amount of each address
    mapping(address => uint256)  private balances ;

    // amounts and timePoints act together(synchronized, but not meaning the 
    //threadsafety here):
    //an address deposits--> msg.value is added to amounts with the transaction count of 
    //the address(for example: if it is the first transaction of the address(msg.sender) 
    //then the count is 0, if it is the second tx than the count of  the second transaction
    //is 1...

    //an address deposits--> block.timestamp is added to timepoints just like in the amounts
    // example: the address 0xabc(symbolic) deposits 1Eth in block.timestamp of  
    mapping(address => mapping(uint256 => uint256)) private  amounts;
    mapping(address => mapping(uint256 => uint256)) private timePoints;
    mapping(address => uint256) private numberOfTx;
   
    uint256 private lockTime;
    uint256 private percentage;
    address private owner;

    //specifies the locktime in seconds and the cut 
    //percentage in case of an early withdraw 
    constructor(uint256 defineLockTime, uint256 cutPercentage){
        lockTime=defineLockTime;
        percentage= cutPercentage;
        owner= msg.sender;
    }

    function deposit() public payable noReentrant{
        uint256 lastTx= numberOfTx[address(msg.sender)];
    
        balances[address(msg.sender)]+= msg.value;
        amounts[address(msg.sender)][lastTx]= msg.value;
        timePoints[address(msg.sender)][lastTx]= block.timestamp;
        numberOfTx[address(msg.sender)]= ++lastTx;
    }

   
    function myTotalBalance() public view returns(uint256) {
       return balances[msg.sender];
    }
    

    function withdrawLoop(uint256 withdrawWeis) internal{
        address msgSender= msg.sender;
        uint256 count;
        uint256 toBeWithdrawn= withdrawWeis;

        while(true){
            //was already withdrawn
            if(timePoints[msgSender][count]==1){
                count++; continue;
            } 
            else if(amounts[msgSender][count]< toBeWithdrawn){
                toBeWithdrawn-=amounts[msgSender][count];
                amounts[msgSender][count]=0;
                timePoints[msgSender][count]=1;
                count++; continue;
            }
            else if(amounts[msgSender][count]>=toBeWithdrawn){
                amounts[msgSender][count]-=toBeWithdrawn;
                toBeWithdrawn=0;
                break;
            }
        }
    }
     

    function withdraw(uint256 withdrawWeis) public payable noReentrant{
        address msgSender= msg.sender;
        uint256 available= withdrawableAmountOfAdress(msgSender) ;
        uint256 toBeWithdrawn= withdrawWeis;

        require(withdrawWeis<= available,
        "your request exceeds the available amount, you can call withdrawEarly");

        (bool success, )= msgSender.call{value: withdrawWeis}("");
        require(success, "Transaction failed, because of unknown reasons");
        balances[msgSender]-=toBeWithdrawn;
        withdrawLoop(toBeWithdrawn);
    }  
            
   

    function withdrawEarly(uint256 withdrawWeis) public payable noReentrant{
        address msgSender= msg.sender;
        uint256 available= withdrawableAmountOfAdress(msgSender);
        uint256 toBeWithdrawn= withdrawWeis;

        require(available<= toBeWithdrawn && balances[msgSender]>=withdrawWeis,
         "you have enough withdrawable funds, use withdraw instead");

        (bool success, )= msgSender.call{ value: (withdrawWeis/100)*(100-percentage) }("");
        require(success, "Transaction failed, because of unknown reasons");
        balances[msgSender]-=toBeWithdrawn;
        withdrawLoop(toBeWithdrawn);
    }


    function withdrawableAmountOfAdress(address adr) private view returns(uint256){
        uint256 jetzt= block.timestamp;
        uint256 amnt;
        uint256 count;
        while(true){
            //no transaction yet 
            if(timePoints[adr][count]==0) {
                break;
            }
            //withdrawn tx, the amount is 0 no need to go further
            else if(timePoints[adr][count]==1) {
                count++; continue;
            }
            //if the deposit was made more than a week ago
            else if(jetzt - timePoints[adr][count] >= lockTime){
                amnt+= amounts[adr][count];
            }
            //if the deposit was not made more than a week ago
            else{
                break;
            }
            count++;
        }
        return amnt;
    }

    function withdrawOnlyOwner(uint256 withdrawWeis) external payable{
        require(msg.sender==owner,"not the owner");
        require(balanceOfBank()>= withdrawWeis, "insufficient funds");
        (bool success, )= owner.call{ value: withdrawWeis }("");
        require(success, "tx failed unknown reasons");
    }

    function withdrawableAmount() public view returns(uint256) {
       return withdrawableAmountOfAdress(msg.sender);
    }

    function balanceOfBank() public view returns(uint256){
        return address(this).balance;
    }
}
