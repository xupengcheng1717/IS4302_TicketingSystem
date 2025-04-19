const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('FestivalToken', function () {
    let festivalToken;
    let owner, addr1, addr2;

    before(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        const FestivalToken = await ethers.getContractFactory('FestivalToken');
        festivalToken = await FestivalToken.deploy(ethers.parseEther('2'));
        await festivalToken.waitForDeployment();

        // Mint some tokens for testing
        await festivalToken.getCredit({ value: ethers.parseEther('10')});
    }) 

    describe('Deployment', function () {
        it("Should deploy with correct owner and rate", async function () {
            expect(await festivalToken.owner()).to.equal(owner.address);
            expect(await festivalToken.getRate()).to.equal(ethers.parseEther('2'));
        })
    })

    describe('Get Credit', function () {
        it('Should allow users to get credit with ETH', async function () {
            await festivalToken.connect(addr1).getCredit({ value: ethers.parseEther('4')});
            expect(await festivalToken.balanceOf(addr1.address)).to.equal(2);

            await festivalToken.connect(addr2).getCredit({ value: ethers.parseEther('6')});
            expect(await festivalToken.balanceOf(addr2.address)).to.equal(3);
        });

        it('Should revert if no ETH is sent', async function () {
            await expect(festivalToken.connect(addr2).getCredit({ value: 0 })).to.be.revertedWith('Must send ETH to receive tokens');
        });

        it('Should emit CreditReceived event', async function () {
            await expect(festivalToken.connect(addr1).getCredit({ value: ethers.parseEther('4') }))
                .to.emit(festivalToken, 'CreditReceived')
                .withArgs(addr1.address, 2);
        });
    })

    describe('Credit Check', function () {
        it('Should return correct credit amount', async function () {
            expect(await festivalToken.connect(addr1).checkCredit()).to.equal(4);
            expect(await festivalToken.connect(addr2).checkCredit()).to.equal(3);
        });
    })

    describe('Credit Transfer', function () {
        it('Should allow users to transfer credit', async function () {
            await festivalToken.connect(addr1).transferCredit(addr2.address, 1);
            expect(await festivalToken.connect(addr1).checkCredit()).to.equal(3);
            expect(await festivalToken.connect(addr2).checkCredit()).to.equal(4);
        });

        it('Should revert if insufficient credit', async function () {
            await expect(festivalToken.connect(addr1).transferCredit(addr2.address, 5)).to.be.revertedWith('Insufficient balance');
        });

        it('Should revert if invalid recipient address', async function () {
            await expect(festivalToken.connect(addr1).transferCredit(ethers.ZeroAddress, 1)).to.be.revertedWith('Invalid recipient address');
        })

        it('Should emit CreditTransferred event', async function () {
            await expect(festivalToken.connect(addr1).transferCredit(addr2.address, 1))
                .to.emit(festivalToken, 'CreditTransferred')
                .withArgs(addr1.address, addr2.address, 1);
        });
    })

    describe('Credit Transfer from', function () {
        it('Should allow the original sender to transfer credit to another account', async function () { 
            expect(await festivalToken.connect(addr1).transferCreditFrom(addr1.address, addr2.address, 1)).to.emit(festivalToken, 'CreditTransferred')
                .withArgs(addr1.address, addr2.address, 1);
            expect(await festivalToken.connect(addr1).checkCredit()).to.equal(1);
        })

        it('Should revert if the sender is not the original sender', async function () {
            await expect(festivalToken.connect(addr1).transferCreditFrom(addr2.address, addr1.address, 1)).to.be.revertedWith("Only the original sender can transfer");
        });

        it('Should revert if recipient is the zero address', async function () {
            await expect(festivalToken.connect(addr1).transferCreditFrom(addr1.address, ethers.ZeroAddress, 1)).to.be.revertedWith('Invalid recipient address');
        }
        )

        it('Should revert if insufficient balance', async function () {
            await expect(festivalToken.connect(addr1).transferCreditFrom(addr1.address, addr2.address, 3)).to.be.revertedWith('Insufficient balance');
        });
    })

    describe('Rate getter and setter', function () {
        it('Should allow owner to set rate', async function () {
            await festivalToken.setRate(ethers.parseEther('3'));
            expect(await festivalToken.getRate()).to.equal(ethers.parseEther('3'));
        });

        it('Should revert if non-owner tries to set rate', async function () {
            await expect(festivalToken.connect(addr1).setRate(ethers.parseEther('4'))).to.be.revertedWithCustomError(festivalToken, "OwnableUnauthorizedAccount");
        });

        it('Should revert if rate is set to non-positive number', async function () {
            await expect(festivalToken.setRate(0)).to.be.revertedWith('Rate must be positive');
        });
    })

    describe('Withdraw', function () {
        it('Should allow token holder to withdraw ETH', async function () {
            const rate = await festivalToken.getRate();
            const initialBalance = await ethers.provider.getBalance(addr1.address);
            expect(await festivalToken.connect(addr1).checkCredit()).to.equal(1)
            await festivalToken.connect(addr1).withdrawCredit(1);
            expect(await festivalToken.connect(addr1).checkCredit()).to.equal(0);
            const finalBalance = await ethers.provider.getBalance(addr1.address);
            // use above to check because the balance may not be exactly equal due to gas fees
            expect(finalBalance).to.be.above(initialBalance)
        });

        it('Should revert if insufficient credit', async function () {
            await expect(festivalToken.connect(addr1).withdrawCredit(5)).to.be.revertedWith('Insufficient balance');
        });

        it('Should revert if non-owner tries to withdraw ETH', async function () {
            await expect(festivalToken.connect(addr1).withdrawETH()).to.be.revertedWithCustomError(festivalToken, "OwnableUnauthorizedAccount");
        });

        it('Should allow owner to withdraw ETH', async function () {
            const initialBalance = await ethers.provider.getBalance(owner.address);
            await festivalToken.withdrawETH();
            const finalBalance = await ethers.provider.getBalance(owner.address);
            expect(finalBalance).to.be.above(initialBalance);
        });

        it('Should revert if contract has no ETH', async function () {
            await expect(festivalToken.withdrawETH()).to.be.revertedWith('No ETH to withdraw');
        });
    })
})