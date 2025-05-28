import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { expect } from "chai";
import { PaymentTracker, InvoiceManager, MockERC20 } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ZeroAddress, parseEther } from "ethers";

describe("PaymentTracker", function () {
    async function deployFixture() {
        const [owner, client, other] = await ethers.getSigners();

        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        const mockToken = await MockERC20Factory.deploy("Mock Token", "MTK", 18);

        const InvoiceManagerFactory = await ethers.getContractFactory("InvoiceManager");
        const invoiceManager = await InvoiceManagerFactory.deploy();

        const PaymentTrackerFactory = await ethers.getContractFactory("PaymentTracker");
        const paymentTracker = await PaymentTrackerFactory.deploy(await invoiceManager.getAddress());

        // Set up authorizations
        await invoiceManager.setPaymentProcessor(await paymentTracker.getAddress(), true);
        await paymentTracker.setTokenApproval(await mockToken.getAddress(), true);

        // Set up token balances and approvals
        await mockToken.mint(await client.getAddress(), parseEther("1000"));
        await mockToken.connect(client).approve(await paymentTracker.getAddress(), parseEther("1000"));

        return { paymentTracker, invoiceManager, mockToken, owner, client, other };
    }

    let paymentTracker: PaymentTracker;
    let invoiceManager: InvoiceManager;
    let mockToken: MockERC20;
    let owner: HardhatEthersSigner;
    let client: HardhatEthersSigner;
    let other: HardhatEthersSigner;

    beforeEach(async function () {
        const fixture = await loadFixture(deployFixture);
        paymentTracker = fixture.paymentTracker;
        invoiceManager = fixture.invoiceManager;
        mockToken = fixture.mockToken;
        owner = fixture.owner;
        client = fixture.client;
        other = fixture.other;
    });

    describe("Token Approval", function () {
        it("should set token approval status", async function () {
            const tokenAddress = await mockToken.getAddress();
            await expect(paymentTracker.setTokenApproval(tokenAddress, true))
                .to.emit(paymentTracker, "TokenApprovalChanged")
                .withArgs(tokenAddress, true);

            expect(await paymentTracker.approvedTokens(tokenAddress)).to.be.true;
        });

        it("should update token approval status", async function () {
            const tokenAddress = await mockToken.getAddress();
            await paymentTracker.setTokenApproval(tokenAddress, false);
            expect(await paymentTracker.approvedTokens(tokenAddress)).to.be.false;
        });
    });

    describe("ETH Payments", function () {
        beforeEach(async function () {
            await invoiceManager.createInvoice(
                await client.getAddress(),
                ZeroAddress,
                parseEther("1"),
                BigInt(Math.floor(Date.now() / 1000) + 86400),
                "ETH Invoice"
            );
        });

        it("should record ETH payment", async function () {
            const amount = parseEther("1");
            
            await expect(paymentTracker.connect(client).recordPayment(0, { value: amount }))
                .to.emit(paymentTracker, "PaymentReceived")
                .withArgs(0, ZeroAddress, await client.getAddress(), amount);

            const payment = await paymentTracker.payments(0);
            expect(payment.invoiceId).to.equal(0);
            expect(payment.token).to.equal(ZeroAddress);
            expect(payment.amount).to.equal(amount);
            expect(payment.payer).to.equal(await client.getAddress());
        });

        it("should revert when paying with wrong amount", async function () {
            await expect(paymentTracker.connect(client).recordPayment(0, { value: 0n }))
                .to.be.revertedWithCustomError(paymentTracker, "InvalidAmount");
        });

        it("should revert when paying non-existent invoice", async function () {
            await expect(paymentTracker.connect(client).recordPayment(999, { value: parseEther("1") }))
                .to.be.revertedWithCustomError(paymentTracker, "InvoiceNotFound");
        });
    });

    describe("Token Payments", function () {
        beforeEach(async function () {
            await invoiceManager.createInvoice(
                await client.getAddress(),
                await mockToken.getAddress(),
                parseEther("100"),
                BigInt(Math.floor(Date.now() / 1000) + 86400),
                "Token Invoice"
            );
        });

        it("should record token payment", async function () {
            const amount = parseEther("100");
            const tokenAddress = await mockToken.getAddress();
            
            await expect(paymentTracker.connect(client).recordTokenPayment(0, tokenAddress, amount))
                .to.emit(paymentTracker, "PaymentReceived")
                .withArgs(0, tokenAddress, await client.getAddress(), amount);

            const payment = await paymentTracker.payments(0);
            expect(payment.invoiceId).to.equal(0);
            expect(payment.token).to.equal(tokenAddress);
            expect(payment.amount).to.equal(amount);
            expect(payment.payer).to.equal(await client.getAddress());
        });

        it("should revert when using unapproved token", async function () {
            const tokenAddress = await mockToken.getAddress();
            await paymentTracker.setTokenApproval(tokenAddress, false);
            await expect(paymentTracker.connect(client).recordTokenPayment(0, tokenAddress, parseEther("100")))
                .to.be.revertedWithCustomError(paymentTracker, "UnapprovedToken");
        });
    });

    describe("Payment Queries", function () {
        beforeEach(async function () {
            // Create ETH and token invoices
            await invoiceManager.createInvoice(
                await client.getAddress(),
                ZeroAddress,
                parseEther("1"),
                BigInt(Math.floor(Date.now() / 1000) + 86400),
                "ETH Invoice"
            );
            await invoiceManager.createInvoice(
                await client.getAddress(),
                await mockToken.getAddress(),
                parseEther("100"),
                BigInt(Math.floor(Date.now() / 1000) + 86400),
                "Token Invoice"
            );

            // Record payments
            await paymentTracker.connect(client).recordPayment(0, { value: parseEther("1") });
            await paymentTracker.connect(client).recordTokenPayment(1, await mockToken.getAddress(), parseEther("100"));
        });

        it("should get individual payment", async function () {
            const payment = await paymentTracker.payments(0);
            expect(payment.invoiceId).to.equal(0);
            expect(payment.token).to.equal(ZeroAddress);
            expect(payment.amount).to.equal(parseEther("1"));
            expect(payment.payer).to.equal(await client.getAddress());
        });

        it("should get all payments", async function () {
            const allPayments = await paymentTracker.getPayments();
            expect(allPayments.length).to.equal(2);
            expect(allPayments[0].token).to.equal(ZeroAddress);
            expect(allPayments[1].token).to.equal(await mockToken.getAddress());
        });

        it("should track total paid per invoice", async function () {
            expect(await paymentTracker.totalPaid(0, ZeroAddress)).to.equal(parseEther("1"));
            expect(await paymentTracker.totalPaid(1, await mockToken.getAddress())).to.equal(parseEther("100"));
        });
    });
});
