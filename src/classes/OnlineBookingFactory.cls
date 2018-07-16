/**
 * @author Ragnar Fjolnisson
 * @date 17/06/2017 (Icelandic National Independence day)
 * @description A factory that makes online booking submission possible.
 *
**/
public class OnlineBookingFactory {

	private BookingRequest request;

	public BookingHelper helper { get; private set; }

	public OnlineBookingFactory(String jsonRequest, Id p_itinerary, Id p_webBookingId) {
		// Parse the request
		this.request = (OnlineBookingFactory.BookingRequest) System.JSON.deserialize(jsonRequest, OnlineBookingFactory.BookingRequest.class);
		// Use BookingHelper to prepare any dependencies for the booking
		this.helper = new BookingHelper(request, p_itinerary, p_webBookingId);
		// Commit work for the itinerary header and passengers.
		this.helper.commitHeaders();
		// Creates an async request for the rest of the booking
		System.enqueueJob(new OnlineBookingAsync(helper));
	}

	public class BookingHelper {

		// Request related information
		private BookingRequest request;

		// Existing data queried based on request
		private Map<Id, KaptioTravel__Price_Category__c> priceCategoryById;
		private Map<String, KaptioTravel__ComponentOption__c> componentOptionByPriceCategoryId;
		private Map<Id, KaptioTravel__BoardBasis__c> boardBasisById;

		// New data created for this particular booking
		public KaptioTravel__Itinerary__c itinerary { get; private set; }
		private KaptioTravel__Transaction__c payment;
		private List<KaptioTravel__Passenger__c> passengers;
		private List<KaptioTravel__Itinerary_Item__c> itineraryItems;
		private Id webBookingId;
		private Logs successLog;
		private Logs errorLog;
		
		private BookingHelper(BookingRequest request, Id p_itineraryId, Id p_webBookingId) {
			// Request related information
			this.request = request;
			this.webBookingId = p_webBookingId;
			this.successLog = new Logs('Success Log', 'WebBookingId, ItineraryId');
			this.errorLog = new Logs('Error Log', 'WebBookingId, Error Message');
			
			this.passengers = buildPassengers(request.passengers);
			// Existing data queried based on request
			queryRecords();

			validate(); // validates that we have enough information at this point to continue!

			// New data created for this particular booking
			this.itinerary = getItinerary(p_itineraryId);

			this.payment = buildPayment(request.payment);
			this.itineraryItems = new List<KaptioTravel__Itinerary_Item__c>();
			if (this.request.package_bookings != null) {
				for (PackageBooking booking : request.package_bookings) {
					Map<Integer, Price> pricesByIndex = buildPriceByIndex(booking.prices_by_index);

					for (Component component : booking.components) {
						for (Selection selection : component.selections) {
							 //create Itinerary Item as package item
							itineraryItems.add(buildPackageService(booking.id, component.component_id, selection, pricesByIndex));
						}
					}
				}
			}
			
			if (request.single_service_bookings != null) {
				for (ServiceBooking booking : request.single_service_bookings) {
					Map<Integer, Price> pricesByIndex = buildPriceByIndex(booking.prices_by_index);
					
					for (Selection selection : booking.selections) {
						//create Itinerary Item as single service
						itineraryItems.add(buildSingleService(selection, pricesByIndex));
					}
				}
			}
		}
		//--------------------------------------------------------------
		// Core validation and DML methods
		//--------------------------------------------------------------
		private void commitHeaders() {

			try {
				this.itinerary = [SELECT KaptioTravel__BookingNumber__c, KaptioTravel__Booking__c FROM KaptioTravel__Itinerary__c WHERE Id = :itinerary.Id LIMIT 1];

				for (KaptioTravel__Passenger__c pax : this.passengers) {
					pax.KaptioTravel__Itinerary__c = itinerary.Id;
				}
				Database.insert(this.passengers);

			} catch(Exception e) {
				this.errorLog.rows.add(this.webBookingId + ', exception caught when saving passengers: ' + e.getMessage() + ' StackTrace: ' + e.getStackTraceString());
				throw new OnlineBookingFactoryException('exception caught when saving passengers: ' + e.getMessage() + ' Stack Trace: ' + e.getStackTraceString());
			}
		}

		public void commitLines() {
			try {
				upsert this.itinerary;

				for (KaptioTravel__Itinerary_Item__c itineraryItem : this.itineraryItems) {
					itineraryItem.KaptioTravel__Itinerary__c = this.itinerary.Id;
				}
				insert this.itineraryItems;

				if (this.payment != null) {
					this.payment.KaptioTravel__Itinerary__c = this.itinerary.Id;
					if ( ! System.Test.isRunningTest()) {
						insert this.payment;
					}
				}

				if (request.mode.equalsIgnoreCase('production')) {
					KaptioTravel.GlobalInventoryService.itineraryItemsRecheckInventory(new Map<Id, SObject>(this.itineraryItems).keySet());
				}
			} catch(Exception e) {
				this.errorLog.rows.add(this.webBookingId + ', exception caught when saving bookings with payment: ' + e.getMessage() + ' StackTrace: ' + e.getStackTraceString());
				throw new OnlineBookingFactoryException('exception caught when saving bookings with payment: ' + e.getMessage() +  + ' Stack Trace: ' + e.getStackTraceString());
			}
		}
		
		private void validate() {
			if (this.request.channel_id == null) {
				this.errorLog.rows.add(this.webBookingId + ', channel_id ' + this.request.channel_id + ' not found.');
				throw new OnlineBookingFactoryException('channel_id ' + this.request.channel_id + ' not found.');
			}

			if (this.request.package_bookings != null) {
				for (PackageBooking packageBooking : this.request.package_bookings) {
					if (String.isBlank(packageBooking.id)) {
						this.errorLog.rows.add(this.webBookingId + ', There is package info without package id.');
						throw new OnlineBookingFactoryException('There is package info without package id.');
					}
				}
			}

			if (this.request.passengers.isEmpty()) {
				this.errorLog.rows.add(this.webBookingId + ', No passengers defined. Booking requires at least 1 passenger.');
				throw new OnlineBookingFactoryException('No passengers defined. Booking requires at least 1 passenger.');
			}
		}
		//--------------------------------------------------------------
		// Query and collection helpers
		//--------------------------------------------------------------
		private void queryRecords() {

			Set<Id> componentIds = new Set<Id>();
			Set<Id> componentOptionIds = new Set<Id>();
			Set<Id> priceCategoryIds = new Set<Id>();
			Set<Id> boardBasisIds = new Set<Id>();
			Set<Id> packageIds = new Set<Id>();

			if (this.request.package_bookings != null) {
				for (PackageBooking booking : this.request.package_bookings) {
					packageIds.add(booking.id);

					for (Component component : booking.components) {
						componentIds.add(component.component_id);

						for (Selection selection : component.selections) {
							componentOptionIds.add(selection.item_option_id);
							boardBasisIds.add(selection.item_type_option_id);
						}
					}
				}
			}
			
			if (this.request.single_service_bookings != null) {
				for (ServiceBooking booking : this.request.single_service_bookings) {
					for (Selection selection : booking.selections) {
						priceCategoryIds.add(selection.item_option_id);
						boardBasisIds.add(selection.item_type_option_id);
					}
				}
			}

			//To exclude NULL value from sets of ids
			componentIds.remove(null);
			componentOptionIds.remove(null);
			priceCategoryIds.remove(null);
			boardBasisIds.remove(null);
			packageIds.remove(null);

			this.componentOptionByPriceCategoryId = new Map<String, KaptioTravel__ComponentOption__c>();
			for (KaptioTravel__ComponentOption__c option : [
					SELECT Id, KaptioTravel__Component__c, KaptioTravel__Item__c,
						KaptioTravel__PriceCategory__c, KaptioTravel__Item__r.KaptioTravel__Supplier__c,
						KaptioTravel__PriceCategory__r.KaptioTravel__ExternalName__c,
						KaptioTravel__Item__r.KaptioTravel__ExternalName__c, KaptioTravel__Item__r.KaptioTravel__TaxGroup__c
					FROM KaptioTravel__ComponentOption__c
					WHERE KaptioTravel__Component__c IN :componentIds
					LIMIT 1000
				]) {

				String key = option.KaptioTravel__Component__c + ':' + option.KaptioTravel__PriceCategory__c;
				this.componentOptionByPriceCategoryId.put(key, option);
			}

			this.priceCategoryById = new Map<Id, KaptioTravel__Price_Category__c>([
				SELECT KaptioTravel__Item__c, KaptioTravel__Item__r.KaptioTravel__Supplier__c,
					KaptioTravel__ExternalName__c, KaptioTravel__Item__r.KaptioTravel__ExternalName__c,
					KaptioTravel__Item__r.KaptioTravel__TaxGroup__c
				FROM KaptioTravel__Price_Category__c
				WHERE Id IN :priceCategoryIds
				LIMIT 1000
			]);

			this.boardBasisById = new Map<Id, KaptioTravel__BoardBasis__c>([
				SELECT Id
				FROM KaptioTravel__BoardBasis__c
				WHERE Id IN :boardBasisIds
				LIMIT 1000
			]);
		}

		private KaptioTravel__Itinerary__c getItinerary(Id p_itineraryId) {
			List<KaptioTravel__Itinerary__c> itineraries = [
				SELECT KaptioTravel__Start_Date__c, KaptioTravel__End_Date__c, CurrencyIsoCode, KaptioTravel__Account__c
				FROM KaptioTravel__Itinerary__c
				WHERE Id = :p_itineraryId
				LIMIT 1
			];
			return (itineraries.isEmpty()) ? null : itineraries.get(0);
		}

		//--------------------------------------------------------------
		// Builders
		//--------------------------------------------------------------

		private Map<Integer, Price> buildPriceByIndex(List<PricesByIndex> p_pricesByIndex) {
			Map<Integer, Price> output = new Map<Integer, Price>();
			for (PricesByIndex index : p_pricesByIndex) {
				output.put(index.index, index.price);
			}
			return output;
		}

		private KaptioTravel__Itinerary_Item__c buildPackageService(Id p_packageId, Id p_componentId, Selection p_selection, Map<Integer, Price> p_priceByIndex) {
			KaptioTravel__ComponentOption__c option = this.componentOptionByPriceCategoryId.get(p_componentId + ':' + p_selection.item_option_id);
			Price selectionPrice = p_priceByIndex.get(p_selection.index);

			return new KaptioTravel__Itinerary_Item__c(
				// Product related
				KaptioTravel__BoardBasis__c = p_selection.item_type_option_id,
				KaptioTravel__Item__c = option.KaptioTravel__Item__c,
				KaptioTravel__Price_Category__c = option.KaptioTravel__PriceCategory__c,
				KaptioTravel__Supplier__c = option.KaptioTravel__Item__r.KaptioTravel__Supplier__c,

				// Booking related
				KaptioTravel__Cancelled__c = false,
				KaptioTravel__IsCustom__c = false,
				KaptioTravel__IsDeleted__c = false,
				KaptioTravel__IsOptional__c = false,
				KaptioTravel__IsVisible__c = true,
				KaptioTravel__DateFrom__c = this.itinerary.KaptioTravel__Start_Date__c,
				KaptioTravel__TimeFrom__c = '12:00',
				KaptioTravel__DateTo__c = this.itinerary.KaptioTravel__End_Date__c,
				KaptioTravel__TimeTo__c = '12:00',
				KaptioTravel__ExternalName__c = option.KaptioTravel__PriceCategory__r.KaptioTravel__ExternalName__c,
				KaptioTravel__FullName__c = option.KaptioTravel__Item__r.KaptioTravel__ExternalName__c,
				KaptioTravel__Quantity__c = p_selection.guests,

				// Package related
				KaptioTravel__AddedToPackageTotal__c = true,
				KaptioTravel__IsPrimaryHoldingPrice__c = false,
				KaptioTravel__IsSecondaryHoldingPrice__c = false,
				KaptioTravel__PackageComponent__c = option.KaptioTravel__Component__c,
				KaptioTravel__PackageComponentOption__c = option.Id,
				KaptioTravel__Package__c = p_packageId,

				// Price related
				CurrencyIsoCode = this.itinerary.CurrencyIsoCode,
				KaptioTravel__CommissionPercent__c = 0,
				KaptioTravel__EstimatedPrice__c = false,
				KaptioTravel__ManualCostPrice__c = false,
				KaptioTravel__ManualSellPrice__c = false,
				KaptioTravel__OverrideNightDayPricing__c = false,
				KaptioTravel__RateCodes__c = null,
				KaptioTravel__ResellerCommissionPercent__c = 0,
				KaptioTravel__ResellerCommissionTotal__c = 0,
				KaptioTravel__SupplierBuyRate__c = 1,
				KaptioTravel__SupplierCommissionTotal__c = 0,
				KaptioTravel__SupplierCurrencyIsoCode__c = selectionPrice.supplier_price.currency_iso_code,
				KaptioTravel__SupplierTotalCost__c = selectionPrice.supplier_price.total,
				KaptioTravel__SupplierUnitCost__c = (selectionPrice.supplier_price.total / p_selection.guests),
				KaptioTravel__Total_Cost__c = selectionPrice.net,
				KaptioTravel__Total_Price__c = selectionPrice.sales,
				KaptioTravel__TotalCommission__c = 0,
				KaptioTravel__TotalPriceNet__c = selectionPrice.sales,
				KaptioTravel__Unit_Cost__c = (selectionPrice.net / p_selection.guests),
				KaptioTravel__Unit_Price__c = (selectionPrice.sales / p_selection.guests),
				KaptioTravel__UnitPriceNet__c = (selectionPrice.sales / p_selection.guests),
				KaptioTravel__Tax_Percent__c = 0,
				KaptioTravel__Tax_Total__c = selectionPrice.tax,
				KaptioTravel__TaxGroupId__c = option.KaptioTravel__Item__r.KaptioTravel__TaxGroup__c
			);
		}

		private KaptioTravel__Itinerary_Item__c buildSingleService(Selection p_selection, Map<Integer, Price> p_priceByIndex) {
			KaptioTravel__Price_Category__c priceCategory = this.priceCategoryById.get(p_selection.item_option_id);
			Price selectionPrice = p_priceByIndex.get(p_selection.index);

			return new KaptioTravel__Itinerary_Item__c(
				// Product related
				KaptioTravel__BoardBasis__c = p_selection.item_type_option_id,
				KaptioTravel__Item__c = priceCategory.KaptioTravel__Item__c,
				KaptioTravel__Price_Category__c = priceCategory.Id,
				KaptioTravel__Supplier__c = priceCategory.KaptioTravel__Item__r.KaptioTravel__Supplier__c,

				// Booking related
				KaptioTravel__Cancelled__c = false,
				KaptioTravel__IsCustom__c = false,
				KaptioTravel__IsDeleted__c = false,
				KaptioTravel__IsOptional__c = false,
				KaptioTravel__IsVisible__c = true,
				KaptioTravel__DateFrom__c = p_selection.date_from,
				KaptioTravel__TimeFrom__c = '12:00',
				KaptioTravel__DateTo__c = (p_selection.date_to != null) ? p_selection.date_to : p_selection.date_from,
				KaptioTravel__TimeTo__c = '12:00',
				KaptioTravel__ExternalName__c = priceCategory.KaptioTravel__ExternalName__c,
				KaptioTravel__FullName__c = priceCategory.KaptioTravel__Item__r.KaptioTravel__ExternalName__c,
				KaptioTravel__Quantity__c = p_selection.guests,

				// Price related
				CurrencyIsoCode = this.itinerary.CurrencyIsoCode,
				KaptioTravel__CommissionPercent__c = 0,
				KaptioTravel__EstimatedPrice__c = false,
				KaptioTravel__ManualCostPrice__c = false,
				KaptioTravel__ManualSellPrice__c = false,
				KaptioTravel__OverrideNightDayPricing__c = false,
				KaptioTravel__RateCodes__c = null,
				KaptioTravel__ResellerCommissionPercent__c = 0,
				KaptioTravel__ResellerCommissionTotal__c = 0,
				KaptioTravel__SupplierBuyRate__c = 1,
				KaptioTravel__SupplierCommissionTotal__c = 0,
				KaptioTravel__SupplierCurrencyIsoCode__c = selectionPrice.supplier_price.currency_iso_code,
				KaptioTravel__SupplierTotalCost__c = selectionPrice.supplier_price.total,
				KaptioTravel__SupplierUnitCost__c = (selectionPrice.supplier_price.total / p_selection.guests),
				KaptioTravel__Total_Cost__c = selectionPrice.net,
				KaptioTravel__Total_Price__c = selectionPrice.sales,
				KaptioTravel__TotalCommission__c = 0,
				KaptioTravel__TotalPriceNet__c = selectionPrice.sales,
				KaptioTravel__Unit_Cost__c = (selectionPrice.net / p_selection.guests),
				KaptioTravel__Unit_Price__c = (selectionPrice.sales / p_selection.guests),
				KaptioTravel__UnitPriceNet__c = (selectionPrice.sales / p_selection.guests),
				KaptioTravel__Tax_Percent__c = 0,
				KaptioTravel__Tax_Total__c = selectionPrice.tax,
				KaptioTravel__TaxGroupId__c = priceCategory.KaptioTravel__Item__r.KaptioTravel__TaxGroup__c
			);
		}

		private List<KaptioTravel__Passenger__c> buildPassengers(List<Passenger> p_passengers) {
			List<KaptioTravel__Passenger__c> output = new List<KaptioTravel__Passenger__c>();

			for (Passenger pax : p_passengers) {
				output.add(
					new KaptioTravel__Passenger__c(
						KaptioTravel__FirstName__c = pax.first_name,
						KaptioTravel__LastName__c = pax.last_name,
						KaptioTravel__Gender__c = pax.gender,
						KaptioTravel__Email__c = pax.email,
						KaptioTravel__Age__c = pax.age
					)
				);
			}

			return output;
		}
		
		private KaptioTravel__Transaction__c buildPayment(Payment payment) {
			if (payment != null) {
				return new KaptioTravel__Transaction__c(
					KaptioTravel__PayerName__c = payment.payer_name,
					KaptioTravel__PayerEmail__c = payment.payer_email,
					KaptioTravel__Payment_Received_DateTime__c = (Datetime)JSON.deserialize('"' + payment.payment_datetime + '"' , Datetime.class),
					KaptioTravel__PaymentInfo__c = payment.additional_info,
					KaptioTravel__PaymentMethod__c = payment.method,
					KaptioTravel__Amount__c = Decimal.valueOf(payment.amount),
					KaptioTravel__Surcharge__c = Decimal.valueOf(payment.surcharge)
				);
			} else {
				return null;
			}
		}
	}

  //--------------------------------------------------------------
  // JSON Parser!
  //--------------------------------------------------------------
	public class BookingRequest {
		public String mode;
		public String currency_iso_code;
		public List<Passenger> passengers;
		public Payment payment;
		public List<PackageBooking> package_bookings;
		public List<ServiceBooking> single_service_bookings;
		public Id channel_id;
	}

	public class Passenger {
		public Integer index;
		public String salutation;
		public String first_name;
		public String last_name;
		public String gender;
		public String email;
		public String type;
		public Integer age;
	}

	public class Payment {
		public String payer_name;
		public String payer_email;
		public String payment_datetime;
		public String additional_info;
		public String method;
		public String amount;
		public String surcharge;
	}

	public class PackageBooking {
		public Id id;
		public Date booking_date;
		public Integer total_people;
		public TotalPrice total_price;
		public List<Component> components;
		public List<PricesByIndex> prices_by_index;
	}

	public class TotalPrice {
		public String currency_iso_code;
		public Decimal net;
		public Decimal sales;
		public SupplierPrice supplier_price;
		public Decimal net_discount;
		public Decimal sales_discount;
		public Decimal tax;
	}

	public class Component {
		public Id component_id;
		public List<Selection> selections;
	}

	public class Selection {
		public Integer index;
		public Integer guests;
		public Id item_type_option_id;
		public Id item_option_id;
		public Date date_from;
		public Date date_to;
	}

	public class PricesByIndex {
		public Integer index;
		public Price price;
	}

	public class Price {
		public Decimal net;
		public Decimal sales;
		public SupplierPrice supplier_price;
		public String currency_iso_code;
		public Decimal net_discount;
		public Decimal sales_discount;
		public Decimal tax;
	}

	public class SupplierPrice {
		public String currency_iso_code;
		public Decimal total;
	}

	public class ServiceBooking {
		public List<Selection> selections;
		public List<PricesByIndex> prices_by_index;
	}
	
	/**
	* @description Apex class for handling success/error logs are related to KaptioAction__c record.
	*/
	public class Logs {
		public String fileName { get; set; }
		public String headers { get; set; }
		public List<String> rows { get; set; }
		
		public Logs(String fileName, String headers) {
			this.fileName = fileName;
			this.headers = headers;
			this.rows = new List<String>();
		}
		
		/**
		* @description Save logs
		* @return void
		*/
		public void insertLog(Id p_webBookingId) {
			if ( ! rows.isEmpty()) {
				Attachment attachment = new Attachment(
					ContentType = 'csv',
					Body = Blob.valueOf(buildBody()),
					Name = fileName + '.csv',
					ParentId = p_webBookingId
				);
				insert attachment;
			}
		}
		
		/**
		* @description Build body of log file
		* @return String
		*/
		private String buildBody() {
			return headers + '\n' + String.join(rows, '\n');
		}
	}

	public class OnlineBookingFactoryException extends Exception {}
}