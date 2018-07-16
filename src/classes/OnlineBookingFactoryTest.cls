@IsTest
private class OnlineBookingFactoryTest {
	
	@testSetup
	private static void setupData() {
		KaptioTravel__AppSettings__c app = KaptioTravel__AppSettings__c.getOrgDefaults();
		app.KaptioTravel__ProfitStrategyCalculation__c = 'Markup';
		upsert app;
		
		KaptioTravel__Brand__c brand = new KaptioTravel__Brand__c(
			Name = 'Simple Business Unit',
			KaptioTravel__BookingNumberSequence__c = 100017.0,
			KaptioTravel__BookingPrefix__c = '1-',
			KaptioTravel__SupplierInvoicePrefix__c = '1',
			KaptioTravel__SalesInvoicePrefix__c = 'XX',
			KaptioTravel__SalesInvoiceSequence__c = 100024.0,
			KaptioTravel__CreditInvoicePrefix__c = 'CC',
			KaptioTravel__CreditInvoiceSequence__c = 1.0
		);
		Database.insert(brand);
		
		KaptioTravel__Channel__c channel = new KaptioTravel__Channel__c(
			Name = 'Test Channel',
			KaptioTravel__ChannelCode__c = 'TTT',
			KaptioTravel__Brand__c = brand.Id,
			KaptioTravel__ActionsJSON__c = '{"stages":[{"stageType":"Itinerary","stageCategory":" Itinerary","publishedItineraryStatus":null,"page":"KaptioTravel__KtCustomerPage","index":2,"emailTemplate":"00Xb0000000hnj4EAA","channel":null,"canExpire":null,"actions":[{"postActionText":"We will get back to you soon.","name":"","lostReasonRequired":null,"label":"Have a question?","index":0,"helpText":"","cssClass":"","commentRequired":false,"commentHelpText":"Thanks!","blocksOtherActions":false,"actionType":"comment","actionPage":null,"actionComment":""}]},{"stageType":"Proposal","stageCategory":"Proposal","publishedItineraryStatus":null,"page":"c__CustomerProposal","index":1,"emailTemplate":"00Xb0000000hnj5EAA","channel":null,"canExpire":true,"actions":[{"postActionText":"Thanks for informing us. We will get back to you in the next few days with a confirmation of your booking.","name":"","lostReasonRequired":false,"label":"Have a question?","index":1,"helpText":"","cssClass":"button blue","commentRequired":false,"commentHelpText":"","blocksOtherActions":false,"actionType":"comment","actionPage":null,"actionComment":"Customer is ready to book."},{"postActionText":"Thanks for your question. We will get back to you in 24 hours.","name":"Customer is interested","lostReasonRequired":false,"label":"Interested","index":2,"helpText":"","cssClass":"button green","commentRequired":false,"commentHelpText":"Have a question?","blocksOtherActions":true,"actionType":"cta","actionPage":null,"actionComment":""},{"postActionText":"Sorry to hear that you are not interested. A customer representative will be in touch.","name":"Customer not interested","lostReasonRequired":false,"label":"Not interested","index":3,"helpText":"","cssClass":"button red","commentRequired":true,"commentHelpText":"Can you tell us a little bit what might be improved?","blocksOtherActions":true,"actionType":"cta","actionPage":null,"actionComment":"Customer is not interested."}]}]}',
			KaptioTravel__AvailableCurrencies__c = 'CAD;DKK;USD;GBP;USD',
			KaptioTravel__ConfirmationPage__c = 'KtCustomerPage',
			KaptioTravel__ContentExpirationDays__c = 30,
			KaptioTravel__ContentExpiredMessage__c = 'Your proposal has expired.',
			KaptioTravel__CustomerConfirmationComment__c = 'Customer approved or confirmed this.',
			KaptioTravel__CustomerOutputErrorMessage__c = 'This page is not available. Please contact us for more info.'
		);
		Database.insert(channel);
		
		List<Account> suppliers = new List<Account> {
			new Account(
				Name = 'Accommodation Supplier',
				RecordTypeId = Account.SObjectType.getDescribe().getRecordTypeInfosByName().get('Supplier').getRecordTypeId()),
			new Account(
				Name = 'Activity Supplier',
				RecordTypeId = Account.SObjectType.getDescribe().getRecordTypeInfosByName().get('Supplier').getRecordTypeId())
		};
		Database.insert(suppliers);
		
		KaptioTravel__Group__c taxGroup = new KaptioTravel__Group__c(KaptioTravel__TypeId__c = '0', KaptioTravel__TypeName__c = 'TaxGroup');
		Database.insert(taxGroup);
		
		List<KaptioTravel__Item__c> items = new List<KaptioTravel__Item__c> {
			new KaptioTravel__Item__c(
				Name = 'Accommodation Item',
				KaptioTravel__Supplier__c = suppliers.get(0).Id,
				KaptioTravel__TaxGroup__c = taxGroup.Id,
				RecordTypeId = KaptioTravel__Item__c.SObjectType.getDescribe().recordTypeInfosByName.get('Accommodation').getRecordTypeId(),
				KaptioTravel__AllocationType__c = 'night'
			),
			new KaptioTravel__Item__c(
				Name = 'Activity Item',
				KaptioTravel__Supplier__c = suppliers.get(1).Id,
				KaptioTravel__TaxGroup__c = taxGroup.Id,
				RecordTypeId = KaptioTravel__Item__c.SObjectType.getDescribe().recordTypeInfosByName.get('Activity').getRecordTypeId(),
				KaptioTravel__AllocationType__c = 'booking'
			)
		};
		//It will insert 9 price categories automatically as it does initial script
		Database.insert(items);
		
		List<KaptioTravel__Price_Category__c> priceCategories = new List<KaptioTravel__Price_Category__c>{
			new KaptioTravel__Price_Category__c(
				Name = 'Double Room',
				KaptioTravel__Item__c = items.get(0).Id,
				KaptioTravel__MaxAdults__c = 2,
				KaptioTravel__Default__c = true),
			new KaptioTravel__Price_Category__c(
				Name = 'Adult',
				KaptioTravel__Item__c = items.get(1).Id,
				KaptioTravel__MaxAdults__c = 1,
				KaptioTravel__Default__c = true)
		};
		Database.insert(priceCategories);
		
		//==========
		// Price Seasons
		//==========
		List<KaptioTravel__PriceSeason__c> priceSeasons = new List<KaptioTravel__PriceSeason__c> {
			new KaptioTravel__PriceSeason__c(
				Name = 'Accommodation Period',
				KaptioTravel__Item__c = items.get(0).Id
			),
			new KaptioTravel__PriceSeason__c(
				Name = 'Activity Period',
				KaptioTravel__Item__c = items.get(1).Id
			)
		};
		Database.insert(priceSeasons);
		
		String wholeWeek = 'Mon;Tue;Wed;Thu;Fri;Sat;Sun';
		List<KaptioTravel__TimePeriod__c> timePeriods = new List<KaptioTravel__TimePeriod__c>{
			new KaptioTravel__TimePeriod__c(
				KaptioTravel__StartDate__c = Date.today(),
				KaptioTravel__EndDate__c = Date.today().addDays(10),
				KaptioTravel__DaysOfWeek__c = wholeWeek,
				KaptioTravel__PriceSeason__c = priceSeasons.get(0).Id
			),
			new KaptioTravel__TimePeriod__c(
				KaptioTravel__StartDate__c = Date.today(),
				KaptioTravel__EndDate__c = Date.today().addDays(10),
				KaptioTravel__DaysOfWeek__c = wholeWeek,
				KaptioTravel__PriceSeason__c = priceSeasons.get(1).Id
			)
		};
		Database.insert(timePeriods);
		
		//Package Setup
		List<KaptioTravel__Package__c> packages = new List<KaptioTravel__Package__c> {
			new KaptioTravel__Package__c(
				Name = 'Package1',
				RecordTypeId = KaptioTravel__Package__c.SObjectType.getDescribe().recordTypeInfosByName.get('Package').getRecordTypeId(),
				KaptioTravel__DepartureTypeId__c = '0', // Anyday
				KaptioTravel__DepartureTypeName__c = 'Anyday',
				KaptioTravel__SellingPriceSetupId__c = '0', // Channel Markup
				KaptioTravel__NetPriceSetupId__c = '1', // Dynamic
				KaptioTravel__IsActive__c = true,
				KaptioTravel__PrepackagedBySingleSupplier__c = false,
				KaptioTravel__Length__c = 5
			),
			new KaptioTravel__Package__c(
				Name = 'Package2',
				RecordTypeId = KaptioTravel__Package__c.SObjectType.getDescribe().recordTypeInfosByName.get('Package').getRecordTypeId(),
				KaptioTravel__DepartureTypeId__c = '0', // Anyday
				KaptioTravel__DepartureTypeName__c = 'Anyday',
				KaptioTravel__SellingPriceSetupId__c = '0', // Channel Markup
				KaptioTravel__NetPriceSetupId__c = '1', // Dynamic
				KaptioTravel__IsActive__c = true,
				KaptioTravel__PrepackagedBySingleSupplier__c = false,
				KaptioTravel__Length__c = 10
			)
		};
		Database.insert(packages);
		
		List<KaptioTravel__Component__c> packageComponents = new List<KaptioTravel__Component__c> {
			new KaptioTravel__Component__c(
				KaptioTravel__ComponentType__c = 'PriceCategories',
				KaptioTravel__SelectionType__c = 'Required', //Required
				KaptioTravel__PricingBehaviorChoice__c = 'Standard', //Standard
				KaptioTravel__RecordType__c = 'Accommodation',
				KaptioTravel__Start__c = 1,
				KaptioTravel__Package__c = packages.get(0).Id),
			new KaptioTravel__Component__c(
				KaptioTravel__ComponentType__c = 'PriceCategories',
				KaptioTravel__SelectionType__c = 'Required', //Required
				KaptioTravel__PricingBehaviorChoice__c = 'Standard', //Standard
				KaptioTravel__RecordType__c = 'Activity',
				KaptioTravel__Start__c = 1,
				KaptioTravel__Package__c = packages.get(0).Id),
			new KaptioTravel__Component__c(
				KaptioTravel__ComponentType__c = 'PriceCategories',
				KaptioTravel__SelectionType__c = 'Required', //Required
				KaptioTravel__PricingBehaviorChoice__c = 'Standard', //Standard
				KaptioTravel__RecordType__c = 'Accommodation',
				KaptioTravel__Start__c = 1,
				KaptioTravel__Package__c = packages.get(1).Id)
		};
		Database.insert(packageComponents);
		
		List<KaptioTravel__ComponentOption__c> packageComponentOptions = new List<KaptioTravel__ComponentOption__c> {
			new KaptioTravel__ComponentOption__c(
				KaptioTravel__Component__c = packageComponents.get(0).Id,
				KaptioTravel__Item__c = items.get(0).Id,
				KaptioTravel__PriceCategory__c = priceCategories.get(0).Id,
				KaptioTravel__Sort__c = 1),
			new KaptioTravel__ComponentOption__c(
				KaptioTravel__Component__c = packageComponents.get(1).Id,
				KaptioTravel__Item__c = items.get(1).Id,
				KaptioTravel__PriceCategory__c = priceCategories.get(1).Id,
				KaptioTravel__Sort__c = 1),
			new KaptioTravel__ComponentOption__c(
				KaptioTravel__Component__c = packageComponents.get(2).Id,
				KaptioTravel__Item__c = items.get(0).Id,
				KaptioTravel__PriceCategory__c = priceCategories.get(0).Id,
				KaptioTravel__Sort__c = 1)
		};
		Database.insert(packageComponentOptions);
	}
	
	@IsTest
	private static void singleBooking_successBehaviour() {
		
		KaptioTravel__Channel__c channel = [SELECT Id FROM KaptioTravel__Channel__c LIMIT 1];
		
		OnlineBookingFactory.BookingRequest bookingRequest = new OnlineBookingFactory.BookingRequest();
		bookingRequest.mode = 'Test';
		bookingRequest.currency_iso_code = UserInfo.getDefaultCurrency();
		bookingRequest.channel_id = channel.Id;
		bookingRequest.payment = generatePayment();
		bookingRequest.passengers = generatePassengers();
		bookingRequest.single_service_bookings = generateSingleBooking();
		
		RestRequest request = new RestRequest();
		request.requestUri = 'https://eu6.salesforce.com/services/apexrest/api/v1.0/submit_booking';
		request.httpMethod = 'POST';
		request.requestBody = Blob.valueOf(JSON.serialize(bookingRequest));
		RestContext.request = request;
		RestContext.response = new RestResponse();
		
		System.Test.startTest();
		
		ApiBooking.Response response = ApiBooking.submit();
		
		System.Test.stopTest();
		
		System.assertNotEquals(null, response.itinerary_id, response.message);
		System.assertNotEquals(null, response.booking_number, response.message);
		System.assertEquals('200', response.status, response.message);
		
		System.assertEquals(0, [SELECT COUNT() FROM Attachment WHERE Name = 'Error Log.csv']);
		
		Map<String, KaptioTravel__Itinerary_Item__c> itineraryItemByCategoryName = new Map<String, KaptioTravel__Itinerary_Item__c>();
		for (KaptioTravel__Itinerary_Item__c itineraryItem : [
				SELECT KaptioTravel__Price_Category__r.Name, KaptioTravel__Unit_Cost__c, KaptioTravel__Unit_Price__c,
					KaptioTravel__SupplierUnitCost__c, KaptioTravel__Total_Cost__c, KaptioTravel__Total_Price__c,
					KaptioTravel__SupplierTotalCost__c, KaptioTravel__Tax_Total__c
				FROM KaptioTravel__Itinerary_Item__c
				WHERE KaptioTravel__Itinerary__c = :response.itinerary_id
				LIMIT 3
			]) {

			itineraryItemByCategoryName.put(itineraryItem.KaptioTravel__Price_Category__r.Name, itineraryItem);
		}

		System.assertEquals(2, itineraryItemByCategoryName.size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(687.92, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(687.92 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Price__c);
		System.assertEquals(109.84, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Tax_Total__c);
		
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(650.34, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(650.34 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Price__c);
		System.assertEquals(97.8, itineraryItemByCategoryName.get('Adult').KaptioTravel__Tax_Total__c);
	}
	
	@IsTest
	private static void packageBooking_successBehaviour() {
		
		KaptioTravel__Channel__c channel = [SELECT Id FROM KaptioTravel__Channel__c LIMIT 1];
		
		OnlineBookingFactory.BookingRequest bookingRequest = new OnlineBookingFactory.BookingRequest();
		bookingRequest.mode = 'Test';
		bookingRequest.currency_iso_code = UserInfo.getDefaultCurrency();
		bookingRequest.channel_id = channel.Id;
		bookingRequest.payment = generatePayment();
		bookingRequest.passengers = generatePassengers();
		bookingRequest.package_bookings = generatePackageBooking('Package1');
		
		RestRequest request = new RestRequest();
		request.requestUri = 'https://eu6.salesforce.com/services/apexrest/api/v1.0/submit_booking';
		request.httpMethod = 'POST';
		request.requestBody = Blob.valueOf(JSON.serialize(bookingRequest));
		RestContext.request = request;
		RestContext.response = new RestResponse();
		
		System.Test.startTest();
		
		ApiBooking.Response response = ApiBooking.submit();
		
		System.Test.stopTest();
		
		System.assertNotEquals(null, response.itinerary_id, response.message);
		System.assertNotEquals(null, response.booking_number, response.message);
		System.assertEquals('200', response.status, response.message);
		
		System.assertEquals(0, [SELECT COUNT() FROM Attachment WHERE Name = 'Error Log.csv']);
		
		KaptioTravel__Package__c pkg = [SELECT Id FROM KaptioTravel__Package__c WHERE Name = 'Package1' LIMIT 1];
		
		Map<String, KaptioTravel__Itinerary_Item__c> itineraryItemByCategoryName = new Map<String, KaptioTravel__Itinerary_Item__c>();
		for (KaptioTravel__Itinerary_Item__c itineraryItem : [
			SELECT KaptioTravel__Price_Category__r.Name, KaptioTravel__Unit_Cost__c, KaptioTravel__Unit_Price__c,
				KaptioTravel__SupplierUnitCost__c, KaptioTravel__Total_Cost__c, KaptioTravel__Total_Price__c,
				KaptioTravel__SupplierTotalCost__c, KaptioTravel__Tax_Total__c
			FROM KaptioTravel__Itinerary_Item__c
			WHERE KaptioTravel__Itinerary__c = :response.itinerary_id AND KaptioTravel__Package__c = :pkg.Id
			LIMIT 3
		]) {
			
			itineraryItemByCategoryName.put(itineraryItem.KaptioTravel__Price_Category__r.Name, itineraryItem);
		}
		
		System.assertEquals(2, itineraryItemByCategoryName.size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(687.92, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(687.92 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Price__c);
		System.assertEquals(109.84, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Tax_Total__c);
		
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(650.34, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(650.34 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Price__c);
		System.assertEquals(97.8, itineraryItemByCategoryName.get('Adult').KaptioTravel__Tax_Total__c);
	}
	
	@IsTest
	private static void bothBooking_successBehaviour() {
		
		KaptioTravel__Channel__c channel = [SELECT Id FROM KaptioTravel__Channel__c LIMIT 1];
		
		List<OnlineBookingFactory.PackageBooking> packageBookings = new List<OnlineBookingFactory.PackageBooking>();
		packageBookings.addAll(generatePackageBooking('Package1'));
		packageBookings.addAll(generatePackageBooking('Package2'));
		
		List<OnlineBookingFactory.ServiceBooking> serviceBookings = new List<OnlineBookingFactory.ServiceBooking>();
		serviceBookings.addAll(generateSingleBooking());
		serviceBookings.addAll(generateSingleBooking());
		
		OnlineBookingFactory.BookingRequest bookingRequest = new OnlineBookingFactory.BookingRequest();
		bookingRequest.mode = 'Test';
		bookingRequest.currency_iso_code = UserInfo.getDefaultCurrency();
		bookingRequest.channel_id = channel.Id;
		bookingRequest.payment = generatePayment();
		bookingRequest.passengers = generatePassengers();
		bookingRequest.package_bookings = packageBookings;
		bookingRequest.single_service_bookings = serviceBookings;
		
		RestRequest request = new RestRequest();
		request.requestUri = 'https://eu6.salesforce.com/services/apexrest/api/v1.0/submit_booking';
		request.httpMethod = 'POST';
		request.requestBody = Blob.valueOf(JSON.serialize(bookingRequest));
		RestContext.request = request;
		RestContext.response = new RestResponse();
		
		System.Test.startTest();
		
		ApiBooking.Response response = ApiBooking.submit();
		
		System.Test.stopTest();
		
		System.assertNotEquals(null, response.itinerary_id, response.message);
		System.assertNotEquals(null, response.booking_number, response.message);
		System.assertEquals('200', response.status, response.message);
		
		System.assertEquals(0, [SELECT COUNT() FROM Attachment WHERE Name = 'Error Log.csv']);
		
		//Handle dingle service items
		Map<String, KaptioTravel__Itinerary_Item__c> itineraryItemByCategoryName = new Map<String, KaptioTravel__Itinerary_Item__c>();
		for (KaptioTravel__Itinerary_Item__c itineraryItem : [
			SELECT KaptioTravel__Price_Category__r.Name, KaptioTravel__Unit_Cost__c, KaptioTravel__Unit_Price__c,
				KaptioTravel__SupplierUnitCost__c, KaptioTravel__Total_Cost__c, KaptioTravel__Total_Price__c,
				KaptioTravel__SupplierTotalCost__c, KaptioTravel__Tax_Total__c
			FROM KaptioTravel__Itinerary_Item__c
			WHERE KaptioTravel__Itinerary__c = :response.itinerary_id AND KaptioTravel__Package__c = null
			LIMIT 5
		]) {
			
			itineraryItemByCategoryName.put(itineraryItem.KaptioTravel__Price_Category__r.Name, itineraryItem);
		}
		
		System.assertEquals(2, itineraryItemByCategoryName.size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(687.92, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(687.92 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Price__c);
		System.assertEquals(109.84, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Tax_Total__c);
		
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(650.34, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(650.34 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Price__c);
		System.assertEquals(97.8, itineraryItemByCategoryName.get('Adult').KaptioTravel__Tax_Total__c);
		
		//Handle package service items
		itineraryItemByCategoryName = new Map<String, KaptioTravel__Itinerary_Item__c>();
		for (KaptioTravel__Itinerary_Item__c itineraryItem : [
			SELECT KaptioTravel__Price_Category__r.Name, KaptioTravel__Unit_Cost__c, KaptioTravel__Unit_Price__c,
				KaptioTravel__SupplierUnitCost__c, KaptioTravel__Total_Cost__c, KaptioTravel__Total_Price__c,
				KaptioTravel__SupplierTotalCost__c, KaptioTravel__Tax_Total__c
			FROM KaptioTravel__Itinerary_Item__c
			WHERE KaptioTravel__Itinerary__c = :response.itinerary_id AND KaptioTravel__Package__c != null
			LIMIT 3
		]) {
			
			itineraryItemByCategoryName.put(itineraryItem.KaptioTravel__Price_Category__r.Name, itineraryItem);
		}
		
		System.assertEquals(2, itineraryItemByCategoryName.size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(687.92, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(687.92 / 2, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Unit_Price__c);
		System.assertEquals(109.84, itineraryItemByCategoryName.get('Double Room').KaptioTravel__Tax_Total__c);
		
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(650.34, itineraryItemByCategoryName.get('Adult').KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(650.34 / 2, itineraryItemByCategoryName.get('Adult').KaptioTravel__Unit_Price__c);
		System.assertEquals(97.8, itineraryItemByCategoryName.get('Adult').KaptioTravel__Tax_Total__c);
	}
	
	@IsTest
	private static void multipleBookings_successBehaviour() {
		KaptioTravel__Channel__c channel = [SELECT Id FROM KaptioTravel__Channel__c LIMIT 1];
		
		List<OnlineBookingFactory.PackageBooking> packageBookings = new List<OnlineBookingFactory.PackageBooking>();
		packageBookings.addAll(generatePackageBooking('Package1'));
		packageBookings.addAll(generatePackageBooking('Package2'));
		
		List<OnlineBookingFactory.ServiceBooking> serviceBookings = new List<OnlineBookingFactory.ServiceBooking>();
		serviceBookings.addAll(generateSingleBooking());
		serviceBookings.addAll(generateSingleBooking());
		
		OnlineBookingFactory.BookingRequest bookingRequest = new OnlineBookingFactory.BookingRequest();
		bookingRequest.mode = 'Test';
		bookingRequest.currency_iso_code = UserInfo.getDefaultCurrency();
		bookingRequest.channel_id = channel.Id;
		bookingRequest.payment = generatePayment();
		bookingRequest.passengers = generatePassengers();
		bookingRequest.package_bookings = packageBookings;
		bookingRequest.single_service_bookings = serviceBookings;
		
		RestRequest request = new RestRequest();
		request.requestUri = 'https://eu6.salesforce.com/services/apexrest/api/v1.0/submit_booking';
		request.httpMethod = 'POST';
		request.requestBody = Blob.valueOf(JSON.serialize(bookingRequest));
		RestContext.request = request;
		RestContext.response = new RestResponse();
		
		System.Test.startTest();
		
		ApiBooking.Response response = ApiBooking.submit();
		
		System.Test.stopTest();
		
		System.assertNotEquals(null, response.itinerary_id, response.message);
		System.assertNotEquals(null, response.booking_number, response.message);
		System.assertEquals('200', response.status, response.message);
		
		System.assertEquals(0, [SELECT COUNT() FROM Attachment WHERE Name = 'Error Log.csv']);
		
		//Handle dingle service items
		Map<String, List<KaptioTravel__Itinerary_Item__c>> itineraryItemByCategoryName = new Map<String, List<KaptioTravel__Itinerary_Item__c>>();
		for (KaptioTravel__Itinerary_Item__c itineraryItem : [
			SELECT KaptioTravel__Price_Category__r.Name, KaptioTravel__Unit_Cost__c, KaptioTravel__Unit_Price__c,
				KaptioTravel__SupplierUnitCost__c, KaptioTravel__Total_Cost__c, KaptioTravel__Total_Price__c,
				KaptioTravel__SupplierTotalCost__c, KaptioTravel__Tax_Total__c
			FROM KaptioTravel__Itinerary_Item__c
			WHERE KaptioTravel__Itinerary__c = :response.itinerary_id AND KaptioTravel__Package__c = null
			LIMIT 5
		]) {
			
			if ( ! itineraryItemByCategoryName.containsKey(itineraryItem.KaptioTravel__Price_Category__r.Name)) {
				itineraryItemByCategoryName.put(itineraryItem.KaptioTravel__Price_Category__r.Name, new List<KaptioTravel__Itinerary_Item__c>());
			}
			itineraryItemByCategoryName.get(itineraryItem.KaptioTravel__Price_Category__r.Name).add(itineraryItem);
		}
		
		System.assertEquals(2, itineraryItemByCategoryName.get('Double Room').size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(687.92, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(687.92 / 2, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Unit_Price__c);
		System.assertEquals(109.84, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Tax_Total__c);
		
		System.assertEquals(2, itineraryItemByCategoryName.get('Adult').size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(650.34, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(650.34 / 2, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Unit_Price__c);
		System.assertEquals(97.8, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Tax_Total__c);
		
		//Handle package service items
		itineraryItemByCategoryName = new Map<String, List<KaptioTravel__Itinerary_Item__c>>();
		for (KaptioTravel__Itinerary_Item__c itineraryItem : [
			SELECT KaptioTravel__Price_Category__r.Name, KaptioTravel__Unit_Cost__c, KaptioTravel__Unit_Price__c,
				KaptioTravel__SupplierUnitCost__c, KaptioTravel__Total_Cost__c, KaptioTravel__Total_Price__c,
				KaptioTravel__SupplierTotalCost__c, KaptioTravel__Tax_Total__c
			FROM KaptioTravel__Itinerary_Item__c
			WHERE KaptioTravel__Itinerary__c = :response.itinerary_id AND KaptioTravel__Package__c != null
			LIMIT 3
		]) {
			
			if ( ! itineraryItemByCategoryName.containsKey(itineraryItem.KaptioTravel__Price_Category__r.Name)) {
				itineraryItemByCategoryName.put(itineraryItem.KaptioTravel__Price_Category__r.Name, new List<KaptioTravel__Itinerary_Item__c>());
			}
			itineraryItemByCategoryName.get(itineraryItem.KaptioTravel__Price_Category__r.Name).add(itineraryItem);
		}
		
		System.assertEquals(2, itineraryItemByCategoryName.get('Double Room').size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(687.92, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(687.92 / 2, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Unit_Price__c);
		System.assertEquals(109.84, itineraryItemByCategoryName.get('Double Room').get(0).KaptioTravel__Tax_Total__c);
		
		System.assertEquals(1, itineraryItemByCategoryName.get('Adult').size(), JSON.serialize(itineraryItemByCategoryName));
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Total_Cost__c);
		System.assertEquals(520.00, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__SupplierTotalCost__c);
		System.assertEquals(650.34, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Total_Price__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Unit_Cost__c);
		System.assertEquals(520.00 / 2, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__SupplierUnitCost__c);
		System.assertEquals(650.34 / 2, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Unit_Price__c);
		System.assertEquals(97.8, itineraryItemByCategoryName.get('Adult').get(0).KaptioTravel__Tax_Total__c);
	}
	
	private static List<OnlineBookingFactory.ServiceBooking> generateSingleBooking() {
		
		KaptioTravel__Price_Category__c doubleRoom = [SELECT Id FROM KaptioTravel__Price_Category__c WHERE Name = 'Double Room' LIMIT 1];
		KaptioTravel__Price_Category__c adultTicket = [SELECT Id FROM KaptioTravel__Price_Category__c WHERE Name = 'Adult' AND KaptioTravel__Item__r.KaptioTravel__RecordTypeDeveloperName__c = 'Activity' LIMIT 1];
		
		//Build Single Service Bookings
		OnlineBookingFactory.Selection selection1 = new OnlineBookingFactory.Selection();
		selection1.index = 1;
		selection1.guests = 2;
		selection1.item_type_option_id = null;
		selection1.item_option_id = doubleRoom.Id;
		selection1.date_from = Date.today();
		selection1.date_to = Date.today().addDays(10);
		
		OnlineBookingFactory.Selection selection2 = new OnlineBookingFactory.Selection();
		selection2.index = 2;
		selection2.guests = 2;
		selection2.item_type_option_id = null;
		selection2.item_option_id = adultTicket.Id;
		selection2.date_from = Date.today();
		selection2.date_to = Date.today();
		
		OnlineBookingFactory.SupplierPrice supplierPrice = new OnlineBookingFactory.SupplierPrice();
		supplierPrice.total = 520.00;
		supplierPrice.currency_iso_code = UserInfo.getDefaultCurrency();
		
		OnlineBookingFactory.Price price1 = new OnlineBookingFactory.Price();
		price1.net = 520.00;
		price1.sales = 687.92;
		price1.supplier_price = supplierPrice;
		price1.net_discount = 0;
		price1.sales_discount = 0;
		price1.currency_iso_code = UserInfo.getDefaultCurrency();
		price1.tax = 109.84;
		
		OnlineBookingFactory.Price price2 = new OnlineBookingFactory.Price();
		price2.net = 520.00;
		price2.sales = 650.34;
		price2.supplier_price = supplierPrice;
		price2.net_discount = 0;
		price2.sales_discount = 0;
		price2.currency_iso_code = UserInfo.getDefaultCurrency();
		price2.tax = 97.8;
		
		OnlineBookingFactory.PricesByIndex pricesByIndex1 = new OnlineBookingFactory.PricesByIndex();
		pricesByIndex1.index = 1;
		pricesByIndex1.price = price1;
		
		OnlineBookingFactory.PricesByIndex pricesByIndex2 = new OnlineBookingFactory.PricesByIndex();
		pricesByIndex2.index = 2;
		pricesByIndex2.price = price2;
		
		OnlineBookingFactory.ServiceBooking service = new OnlineBookingFactory.ServiceBooking();
		service.selections = new List<OnlineBookingFactory.Selection> {selection1, selection2};
		service.prices_by_index = new List<OnlineBookingFactory.PricesByIndex>{pricesByIndex1, pricesByIndex2};
		
		return new List<OnlineBookingFactory.ServiceBooking>{service};
	}
	
	private static List<OnlineBookingFactory.PackageBooking> generatePackageBooking(String p_packageName) {
		
		KaptioTravel__Package__c pkg = [SELECT Id FROM KaptioTravel__Package__c WHERE Name = :p_packageName LIMIT 1];
		KaptioTravel__ComponentOption__c doubleRoomOption = [SELECT KaptioTravel__Component__c, KaptioTravel__PriceCategory__c FROM KaptioTravel__ComponentOption__c WHERE KaptioTravel__Component__r.KaptioTravel__RecordType__c = 'Accommodation' LIMIT 1];
		KaptioTravel__ComponentOption__c adultTicketOption = [SELECT KaptioTravel__Component__c, KaptioTravel__PriceCategory__c FROM KaptioTravel__ComponentOption__c WHERE KaptioTravel__Component__r.KaptioTravel__RecordType__c = 'Activity' LIMIT 1];
		
		OnlineBookingFactory.SupplierPrice supplierPrice = new OnlineBookingFactory.SupplierPrice();
		supplierPrice.total = 520.00;
		supplierPrice.currency_iso_code = UserInfo.getDefaultCurrency();
		
		OnlineBookingFactory.Price price1 = new OnlineBookingFactory.Price();
		price1.net = 520.00;
		price1.sales = 687.92;
		price1.supplier_price = supplierPrice;
		price1.net_discount = 0;
		price1.sales_discount = 0;
		price1.currency_iso_code = UserInfo.getDefaultCurrency();
		price1.tax = 109.84;
		
		OnlineBookingFactory.Price price2 = new OnlineBookingFactory.Price();
		price2.net = 520.00;
		price2.sales = 650.34;
		price2.supplier_price = supplierPrice;
		price2.net_discount = 0;
		price2.sales_discount = 0;
		price2.currency_iso_code = UserInfo.getDefaultCurrency();
		price2.tax = 97.8;
		
		OnlineBookingFactory.PricesByIndex pricesByIndex1 = new OnlineBookingFactory.PricesByIndex();
		pricesByIndex1.index = 1;
		pricesByIndex1.price = price1;
		
		OnlineBookingFactory.PricesByIndex pricesByIndex2 = new OnlineBookingFactory.PricesByIndex();
		pricesByIndex2.index = 2;
		pricesByIndex2.price = price2;
		
		OnlineBookingFactory.TotalPrice totalPrice = new OnlineBookingFactory.TotalPrice();
		totalPrice.currency_iso_code = UserInfo.getDefaultCurrency();
		totalPrice.net = 1920.00;
		totalPrice.sales = 2540.00;
		totalPrice.supplier_price = supplierPrice;
		totalPrice.net_discount = 0;
		totalPrice.sales_discount = 0;
		totalPrice.tax = 405.56;
		
		//Build Single Service Bookings
		OnlineBookingFactory.Selection selection1 = new OnlineBookingFactory.Selection();
		selection1.index = 1;
		selection1.guests = 2;
		selection1.item_type_option_id = null;
		selection1.item_option_id = doubleRoomOption.KaptioTravel__PriceCategory__c;
		selection1.date_from = Date.today();
		selection1.date_to = Date.today().addDays(10);
		
		OnlineBookingFactory.Selection selection2 = new OnlineBookingFactory.Selection();
		selection2.index = 2;
		selection2.guests = 2;
		selection2.item_type_option_id = null;
		selection2.item_option_id = adultTicketOption.KaptioTravel__PriceCategory__c;
		selection2.date_from = Date.today();
		selection2.date_to = Date.today();
		
		OnlineBookingFactory.Component component1 = new OnlineBookingFactory.Component();
		component1.component_id = doubleRoomOption.KaptioTravel__Component__c;
		component1.selections = new List<OnlineBookingFactory.Selection>{selection1};
		
		OnlineBookingFactory.Component component2 = new OnlineBookingFactory.Component();
		component2.component_id = adultTicketOption.KaptioTravel__Component__c;
		component2.selections = new List<OnlineBookingFactory.Selection>{selection2};
		
		OnlineBookingFactory.PackageBooking packageBooking = new OnlineBookingFactory.PackageBooking();
		packageBooking.id = pkg.Id;
		packageBooking.booking_date = Date.today();
		packageBooking.total_people = 2;
		packageBooking.total_price = totalPrice;
		packageBooking.prices_by_index = new List<OnlineBookingFactory.PricesByIndex>{pricesByIndex1, pricesByIndex2};
		packageBooking.components = new List<OnlineBookingFactory.Component>{component1, component2};
		
		return new List<OnlineBookingFactory.PackageBooking> {packageBooking};
	}
	
	private static List<OnlineBookingFactory.Passenger> generatePassengers() {
		//Build Passengers
		OnlineBookingFactory.Passenger passenger1 = new OnlineBookingFactory.Passenger();
		passenger1.index = 1;
		passenger1.salutation = 'Mr';
		passenger1.first_name = 'Steve';
		passenger1.last_name = 'Lukather';
		passenger1.gender = 'male';
		passenger1.email = 'steve@test.com';
		passenger1.type = 'adult';
		passenger1.age = 43;
		
		OnlineBookingFactory.Passenger passenger2 = new OnlineBookingFactory.Passenger();
		passenger1.index = 2;
		passenger1.salutation = 'Ms';
		passenger1.first_name = 'Stevie';
		passenger1.last_name = 'Nicks';
		passenger1.gender = 'female';
		passenger1.email = 'stevie@test.com';
		passenger1.type = 'adult';
		passenger1.age = 43;
		
		return new List<OnlineBookingFactory.Passenger> {passenger1, passenger2};
	}
	
	private static OnlineBookingFactory.Payment generatePayment() {
		OnlineBookingFactory.Payment payment = new OnlineBookingFactory.Payment();
		payment.payer_name = 'Rick Davies';
		payment.payer_email = 'rickie@outlook.com';
		payment.payment_datetime = '2016-11-04T09:30:57.000+0000';
		payment.additional_info = 'transaction 83984';
		payment.method = 'stripe-visa';
		payment.amount = '17973.00';
		payment.surcharge = '0.00';
		
		return payment;
	}
}