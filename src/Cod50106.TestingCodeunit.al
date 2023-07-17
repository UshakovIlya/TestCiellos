codeunit 50106 MyTestCodeunit
{

    Subtype = Test;
    TestPermissions = Disabled;


    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure TestCreateItem()
    var
        Item: Record Item;
    begin
        InventoryLib.CreateItem(Item);
        Item."Unit Cost" := Random(100);
        Item.Modify();

        GlobalItemID := Item."No.";
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure TestCreateCustomer()
    var
        Customer: Record Customer;
    begin
        SalesLib.CreateCustomer(Customer);
        GlobalCustomerID := Customer."No.";
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure TestCreatePostCustOrder()
    var
        PostCustOrder: Record "Posted Customer Order Header";
        Customer: Record Customer;
    begin
        Customer.get(GlobalCustomerID);
        CreatePostCustOrderHeader(PostCustOrder, Customer);


        GlobalCustOrderHeaderID := PostCustOrder."Order No";
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler,PostCustOrderPageHandler')]
    procedure PostCustomerOrder()
    var
        CustomerOrderHeader: Record "Customer Order Header";
        CustomerOrderHeader2: Record "Customer Order Header";
        CustomerOrderLine: Record "Customer Order Line New";
        PostMgt: Codeunit PostingMgt;
        Customer: Record Customer;
        Item: Record Item;
        CustOrderPage: TestPage "Customer Order";
    begin

        // [GIVEN] New Customer
        // SalesLib.CreateCustomer(Customer);
        Customer.get(GlobalCustomerID);
        // [GIVEN] New Item
        // InventoryLib.CreateItem(Item);
        // Item."Unit Cost" := Random(100);
        Item.Get(GlobalItemID);
        // Item.Modify();

        // [GIVEN] Not Posted Customer Order
        CreateCustOrderHeader(CustomerOrderHeader, Customer);
        // [GIVEN] Not Posted Customer Line
        CreateCustOrderLine(CustomerOrderLine, Item, CustomerOrderHeader);

        // [WHEN] Post order
        CustOrderPage.OpenView();
        CustOrderPage.GoToRecord(CustomerOrderHeader);
        CustomerOrderHeader.CalcFields("Order Amount");
        CustOrderPage.PostOrder.Invoke();

        // [THEN] Check result
        CustomerOrderHeader2.SetRange("Order No", CustomerOrderHeader."Order No");
        Assert.RecordIsEmpty(CustomerOrderHeader2);
    end;

    [Test]
    // [HandlerFunctions('ConfirmHandler')]
    procedure PostCustomerOrderZeroAmount()
    var
        CustomerOrderHeader: Record "Customer Order Header";
        CustomerOrderLine: Record "Customer Order Line New";
        PostMgt: Codeunit PostingMgt;
        Customer: Record Customer;
        Item: Record Item;
        CustOrderPage: TestPage "Customer Order";
        TOtalAmountErr: Label 'Total amount can`t be 0';
    begin

        // [GIVEN] New Customer
        // SalesLib.CreateCustomer(Customer);
        Customer.get(GlobalCustomerID);
        // [GIVEN] New Item
        // InventoryLib.CreateItem(Item);
        // Item."Unit Cost" := Random(100);
        Item.Get(GlobalItemID);
        // Item.Modify();

        // [GIVEN] Not Posted Customer Order
        CreateCustOrderHeader(CustomerOrderHeader, Customer);

        // [WHEN] Post order
        asserterror PostMgt.PostCustOrders(CustomerOrderHeader);

        // [THEN] check the error
        Assert.ExpectedError(TOtalAmountErr);
    end;

    [Test]
    [HandlerFunctions('BeyondPaymentPageHandler')]
    procedure PaymentProcessBeyondOrderAmount()
    var
        PostedCustomerOrderHeader: Record "Posted Customer Order Header";
        PostedCustomerOrderLine: Record "Posted Customer Order Line New";
        Payment: Record "Customer Order Payment";
        PostMgt: Codeunit PostingMgt;
        Customer: Record Customer;
        Item: Record Item;
        PostedCustOrder: TestPage "Posted Customer Order";
        XAmount: Decimal;
        NotSuffAmount: Label 'Not Sufficien amount in Payment';
    begin

        // [GIVEN] New Customer
        // SalesLib.CreateCustomer(Customer);
        Customer.get(GlobalCustomerID);
        // [GIVEN] New Item
        // InventoryLib.CreateItem(Item);
        // Item."Unit Cost" := Random(100);
        Item.Get(GlobalItemID);
        // Item.Modify();

        // [GIVEN] Posted Customer Order
        PostedCustomerOrderHeader.Get(GlobalCustOrderHeaderID);
        // [GIVEN] Posted Customer Line
        // CreatePostCustOrderLine(PostedCustomerOrderLine, Item, PostedCustomerOrderHeader);

        // [When] Create Payment
        PostedCustOrder.OpenView();
        PostedCustOrder.GoToRecord(PostedCustomerOrderHeader);
        asserterror PostedCustOrder.SetPayment.Invoke();

        // [THEN] Check result
        Assert.ExpectedError(NotSuffAmount);

        PostedCustOrder.Close();
    end;




    [Test]
    [HandlerFunctions('PaymentPageHandler')]
    procedure PaymentProcess()
    var
        PostedCustomerOrderHeader: Record "Posted Customer Order Header";
        PostedCustomerOrderLine: Record "Posted Customer Order Line New";
        Payment: Record "Customer Order Payment";
        PostMgt: Codeunit PostingMgt;
        Customer: Record Customer;
        Item: Record Item;
        PostedCustOrder: TestPage "Posted Customer Order";
        XAmount: Decimal;
    begin

        // [GIVEN] New Customer
        // SalesLib.CreateCustomer(Customer);
        Customer.get(GlobalCustomerID);
        // [GIVEN] New Item
        // InventoryLib.CreateItem(Item);
        // Item."Unit Cost" := Random(100);
        Item.Get(GlobalItemID);
        // Item.Modify();


        // [GIVEN] Posted Customer Order
        CreatePostCustOrderHeader(PostedCustomerOrderHeader, Customer);
        // PostedCustomerOrderHeader.Get(GlobalCustOrderHeaderID);
        // [GIVEN] Posted Customer Line
        CreatePostCustOrderLine(PostedCustomerOrderLine, Item, PostedCustomerOrderHeader);

        XAmount := PostedCustomerOrderHeader."Remaining Amount";

        // [When] Create Payment
        PostedCustOrder.OpenView();
        PostedCustOrder.GoToRecord(PostedCustomerOrderHeader);
        PostedCustOrder.SetPayment.Invoke();
        PostedCustOrder.Close();

        // [THEN] Check result
        Assert.AreEqual(XAmount, PostedCustomerOrderHeader."Remaining Amount", 'What even should be here?');
    end;

    [Test]
    [HandlerFunctions('ShowPaymReqPageHandler')]
    procedure TestingTheReportCustomerOrder();
    var
        XmlParameters: Text;
        LibraryReportDataset: Codeunit "Library - Report Dataset";
        PostedCustomerOrderHeader: Record "Posted Customer Order Header";
    begin
        XmlParameters := Report.RunRequestPage(Report::" Posted Customer Orders");
        LibraryReportDataset.RunReportAndLoad(Report::" Posted Customer Orders", PostedCustomerOrderHeader, XmlParameters);

        PostedCustomerOrderHeader.FindFirst();
        // Verifying Order_No on Report. 
        LibraryReportDataset.AssertElementWithValueExists('Order_No', PostedCustomerOrderHeader."Order No");
    end;

    [Test]
    [HandlerFunctions('ShowPaymReqPageHandler')]
    procedure TestingTheReportCustomerPayment();
    var
        XmlParameters: Text;
        LibraryReportDataset: Codeunit "Library - Report Dataset";
        PostedCustomerOrderHeader: Record "Posted Customer Order Header";
        Payment: Record "Customer Order Payment";
    begin
        XmlParameters := Report.RunRequestPage(Report::" Posted Customer Orders");
        LibraryReportDataset.RunReportAndLoad(Report::" Posted Customer Orders", PostedCustomerOrderHeader, XmlParameters);

        Payment.SetRange(PAid, true);
        Payment.FindFirst();
        // Verifying Payment_No on Report. 
        LibraryReportDataset.AssertElementWithValueExists('Payment_No', Payment."Payment No");
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler')]
    procedure TestDeleteCustomer()
    var
        Customer: Record Customer;
        Customer2: Record Customer;
        CustCard: TestPage "Customer Card";
    begin
        // [GIVEN] New Customer
        SalesLib.CreateCustomer(Customer);

        // [When] Delete Cust
        CustCard.OpenView();
        CustCard.GoToRecord(Customer);
        CustCard.DelRec.Invoke();

        // [THEN] Check result
        Customer2.SetRange("No.", Customer."No.");
        Assert.RecordIsEmpty(Customer2);
    end;


    [RequestPageHandler]
    procedure ShowPaymReqPageHandler(var PostCustOrd: TestRequestPage " Posted Customer Orders");
    begin
        // Empty handler used to close the request page
    end;


    [ConfirmHandler]
    procedure ConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;


    [PageHandler]
    procedure PostCustOrderPageHandler(var PostCustOrdPage: Page "Posted Customer Order");
    begin
        PostCustOrdPage.Close();
    end;

    [ModalPageHandler]
    procedure PaymentPageHandler(var PaymentsLookup: TestPage PaymentsLookup);
    var
        Payment: Record "Customer Order Payment";
    begin
        Payment.Init();
        Payment."Customer No" := GlobalPostedCustomerOrderHeader.Customer;
        Payment."Customer Order No" := GlobalPostedCustomerOrderHeader."Order No";
        Payment.Amount := Random(GlobalPostedCustomerOrderHeader."Order Amount");
        Payment.Insert(true);

        PaymentsLookup.OK().Invoke();
    end;

    [ModalPageHandler]
    procedure BeyondPaymentPageHandler(var PaymentsLookup: TestPage PaymentsLookup);
    var
        Payment: Record "Customer Order Payment";
    begin
        PaymentsLookup.PaymentsSubform.Amount.SetValue(100);
        PaymentsLookup.OK().Invoke();
    end;

    procedure CreateCustOrderHeader(var CustomerOrderHeader: Record "Customer Order Header"; Customer: Record Customer)
    begin
        CustomerOrderHeader.Init();

        CustomerOrderHeader.Validate(Customer, Customer."No.");
        CustomerOrderHeader."Document Date" := WorkDate();
        CustomerOrderHeader.SetAutoCalcFields("Order Amount");
        CustomerOrderHeader.Insert(true);
    end;

    procedure CreateCustOrderLine(var CustomerOrderLine: Record "Customer Order Line new"; Item: Record Item; var CustomerOrderHeader: Record "Customer Order Header")
    begin
        CustomerOrderLine.Init();

        CustomerOrderLine."Order No" := CustomerOrderHeader."Order No";
        CustomerOrderLine.Validate("Item No", Item."No.");
        CustomerOrderLine.Validate(Qty, Random(5));
        CustomerOrderLine.Insert(true);
    end;

    procedure CreatePostCustOrderHeader(var PostCustomerOrderHeader: Record "Posted Customer Order Header"; Customer: Record Customer)
    begin
        PostCustomerOrderHeader.Init();

        PostCustomerOrderHeader.Validate(Customer, Customer."No.");
        PostCustomerOrderHeader."Document Date" := WorkDate();
        PostCustomerOrderHeader.Insert(true);
    end;

    procedure CreatePostCustOrderLine(var PostCustomerOrderLine: Record "Posted Customer Order Line new"; Item: Record Item; var PostCustomerOrderHeader: Record "Posted Customer Order Header")
    begin
        PostCustomerOrderLine.Init();
        PostCustomerOrderLine."Order No" := PostCustomerOrderHeader."Order No";
        PostCustomerOrderLine.Validate("Item No", Item."No.");
        PostCustomerOrderLine.Validate(Qty, Random(5));
        PostCustomerOrderLine.Insert(true);
        PostCustomerOrderHeader."Order Amount" := PostCustomerOrderLine."Total Amount";
        PostCustomerOrderHeader."Remaining Amount" := PostCustomerOrderHeader."Order Amount";
        PostCustomerOrderHeader.Modify(true);
    end;

    // procedure CreatePayment(var Payment: Record "Customer Order Payment"; var CustomerOrderHeader: Record "Customer Order Header")
    // begin
    //     Payment.Init();
    //     Payment.
    // end;

    var
        GlobalItemID: code[20];
        GlobalCustomerID: Code[20];
        GlobalCustOrderHeaderID: Code[20];
        GlobalPostedCustomerOrderHeader: Record "Posted Customer Order Header";
        SalesLib: Codeunit "Library - Sales";
        InventoryLib: Codeunit "Library - Inventory";
        Assert: Codeunit Assert;

}
