import { ethers } from "hardhat";
import { expect } from "chai";
import { InvoiceManager, MockERC20 } from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ZeroAddress, parseEther } from "ethers";

describe("InvoiceManager", function () {
    let invoiceManager: InvoiceManager;
    let mockToken: MockERC20;
    let owner: HardhatEthersSigner;
    let client: HardhatEthersSigner;
    let other: HardhatEthersSigner;

    beforeEach(async function () {
        [owner, client, other] = await ethers.getSigners();

        // Deploy MockERC20
        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        mockToken = await MockERC20Factory.deploy("Mock Token", "MTK", 18);

        // Deploy InvoiceManager
        const InvoiceManagerFactory = await ethers.getContractFactory("InvoiceManager");
        invoiceManager = await InvoiceManagerFactory.deploy();

        // Mint some tokens to the client
        await mockToken.mint(await client.getAddress(), parseEther("1000"));
    });

    describe("Invoice Creation", function () {
        it("should create an invoice with ETH payment", async function () {
            const amount = parseEther("1");
            const dueDate = (await time.latest()) + 86400; // 1 day from now
              const tx = await invoiceManager.createInvoice(
                await client.getAddress(),
                ZeroAddress,
                amount,
                dueDate,
                "Test Invoice"
            );
            await expect(tx)
                .to.emit(invoiceManager, "InvoiceCreated")
                .withArgs(0, await client.getAddress(), ZeroAddress, amount, dueDate, "Test Invoice");

            const invoice = await invoiceManager.getInvoice(0);
            expect(invoice.client).to.equal(await client.getAddress());
            expect(invoice.token).to.equal(ZeroAddress);
            expect(invoice.amount).to.equal(amount);
            expect(invoice.dueDate).to.equal(dueDate);
            expect(invoice.paid).to.be.false;
        });

        it("should create an invoice with token payment", async function () {
            const amount = parseEther("100");
            const dueDate = (await time.latest()) + 86400;
            const tokenAddress = await mockToken.getAddress();

            await expect(invoiceManager.createInvoice(
                await client.getAddress(),
                tokenAddress,
                amount,
                dueDate,
                "Token Invoice"
            ))
                .to.emit(invoiceManager, "InvoiceCreated")
                .withArgs(0, await client.getAddress(), tokenAddress, amount, dueDate, "Token Invoice");

            const invoice = await invoiceManager.getInvoice(0);
            expect(invoice.token).to.equal(tokenAddress);
        });        it("should revert when creating invoice with zero amount", async function () {
            const dueDate = (await time.latest()) + 86400;
            await expect(invoiceManager.createInvoice(
                await client.getAddress(),
                ZeroAddress,
                0,
                dueDate,
                "Zero Invoice"
            )).to.be.revertedWithCustomError(invoiceManager, "InvalidAmount");
        });
    });

    describe("Invoice Management", function () {
        beforeEach(async function () {
            // Create a test invoice
            const amount = parseEther("1");
            const dueDate = (await time.latest()) + 86400;
            await invoiceManager.createInvoice(
                await client.getAddress(),
                ZeroAddress,
                amount,
                dueDate,
                "Test Invoice"
            );
        });

        it("should mark invoice as paid by client", async function () {
            await expect(invoiceManager.connect(client).markAsPaid(0))
                .to.emit(invoiceManager, "InvoicePaid")
                .withArgs(0);

            const invoice = await invoiceManager.getInvoice(0);
            expect(invoice.paid).to.be.true;
        });

        it("should mark invoice as paid by owner", async function () {
            await expect(invoiceManager.markAsPaid(0))
                .to.emit(invoiceManager, "InvoicePaid")
                .withArgs(0);

            const invoice = await invoiceManager.getInvoice(0);
            expect(invoice.paid).to.be.true;
        });        it("should revert when unauthorized user tries to mark as paid", async function () {
            await expect(invoiceManager.connect(other).markAsPaid(0))
                .to.be.revertedWithCustomError(invoiceManager, "Unauthorized");
        });

        it("should revert when trying to mark already paid invoice", async function () {
            await invoiceManager.markAsPaid(0);
            await expect(invoiceManager.markAsPaid(0))
                .to.be.revertedWith("Already paid");
        });
    });

    describe("Due Invoices", function () {
        it("should return correct due invoices", async function () {
            const now = await time.latest();
            const pastDue = now - 86400; // 1 day ago
            const futureDue = now + 86400; // 1 day from now
            
            // Create 3 invoices: past due, future due, and one that's paid
            await invoiceManager.createInvoice(
                await client.getAddress(), 
                ZeroAddress, 
                parseEther("1"), 
                pastDue, 
                "Past Due"
            );
            await invoiceManager.createInvoice(
                await client.getAddress(), 
                ZeroAddress, 
                parseEther("1"), 
                futureDue, 
                "Future Due"
            );
            await invoiceManager.createInvoice(
                await client.getAddress(), 
                ZeroAddress, 
                parseEther("1"), 
                pastDue, 
                "Paid"
            );
            
            // Mark one invoice as paid
            await invoiceManager.markAsPaid(2);

            // Get due invoices
            const dueInvoices = await invoiceManager.getDueInvoices();
            
            // Should only return the past due unpaid invoice
            expect(dueInvoices.length).to.equal(1);
            expect(dueInvoices[0].id).to.equal(0);
            expect(dueInvoices[0].dueDate).to.equal(pastDue);
            expect(dueInvoices[0].paid).to.be.false;
        });
    });

    describe("Payment Processor Management", function () {
        it("should allow owner to authorize payment processor", async function () {
            await expect(invoiceManager.setPaymentProcessor(await other.getAddress(), true))
                .to.emit(invoiceManager, "PaymentProcessorUpdated")
                .withArgs(await other.getAddress(), true);

            expect(await invoiceManager.authorizedPaymentProcessors(await other.getAddress())).to.be.true;
        });

        it("should allow owner to revoke payment processor", async function () {
            await invoiceManager.setPaymentProcessor(await other.getAddress(), true);
            await invoiceManager.setPaymentProcessor(await other.getAddress(), false);
            expect(await invoiceManager.authorizedPaymentProcessors(await other.getAddress())).to.be.false;
        });

        it("should revert when non-owner tries to set payment processor", async function () {
            await expect(invoiceManager.connect(other).setPaymentProcessor(await other.getAddress(), true))
                .to.be.revertedWithCustomError(invoiceManager, "Unauthorized");
        });
    });
});