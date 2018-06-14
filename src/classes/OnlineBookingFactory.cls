/**
 * @author Ragnar Fjolnisson
 * @date 17/06/2017 (Icelandic National Independence day)
 * @description A factory that makes online booking submission possible.
 *
**/

public class OnlineBookingFactory {

  @testVisible 
  private BookingRequest request; 
  
  public BookingHelper helper { get; private set; }

  public OnlineBookingFactory(String jsonRequest){
    
    //Auto-pax insert does not apply for online bookings
    ItineraryService.disabledAutomaticCreatePassenges = true;
    // Parse the request
    this.request = parse(jsonRequest);
    // Use BookingHelper to prepare any dependencies for the booking
    this.helper = new BookingHelper(request);
    // Commit work for the itinerary header and passengers.
    this.helper.commitHeaders();
    // Creates an async request for the rest of the booking
    Id jobID = System.enqueueJob( new OnlineBookingAsync(helper));
  }

  public class BookingHelper {

    // Request related information
    private BookingRequest request;
    private Map<Integer, Price> priceByIndex;

    // Existing data queried based on request
    private KaptioTravel__Channel__c channel;
    private KaptioTravel__Package__c pkg;
    private KaptioTravel__BoardBasis__c boardbasis;
    private Sailing__c sailing;
    private Map<String, KaptioTravel__Component__c> packageComponentsByCode;

    // New data created for this particular booking
    private Account primaryAccount;
    public KaptioTravel__Itinerary__c itinerary { get; private set; }
    private KaptioTravel__ItineraryBooking__c packageBooking;
    private List<RoomDto> rooms;
    private List<ItineraryItemsByItineraryBooking> itineraryitemsByItineraryBooking;
    private Map<Integer, KaptioTravel__Passenger__c> passengersByIndex;
    private KaptioTravel__Transaction__c payment;
    private KaptioTravel__ComponentOption__c allInclusivePackageOption;

    private BookingHelper(BookingRequest request){
      
      // Request related information
      this.request = request;
      this.priceByIndex = buildPriceByIndex();

      // Existing data queried based on request
      this.channel = getChannel(request.channel_id);
      this.pkg = getPackage(request.package_booking.parameters.package_code);
      
      this.boardbasis = getBoardBasis();
      this.allInclusivePackageOption = getAllInclusivePackageOption();
      this.packageComponentsByCode = getPackageComponentsByCode();
      this.sailing = getSailing();
      
      validate(); // validates that we have enough information at this point to continue!

      // New data created for this particular booking
      this.rooms = new List<RoomDto>();
      this.primaryAccount = buildPrimaryAccount(request.passengers[0]);
      this.itinerary = buildItinerary();
      this.passengersByIndex = buildPassengersByIndex(request.passengers);
      system.debug('request:' + request.payment);
      this.payment = buildPayment(request.payment);
      system.debug('payment:' + payment);
      this.packageBooking = buildPackageBooking();
      this.itineraryitemsByItineraryBooking = new List<ItineraryItemsByItineraryBooking>();
      for(Integer i = 0; i < request.package_booking.parameters.cabins.size(); i++){ // list of a list
        for(Cabins service : request.package_booking.parameters.cabins[i]){
          itineraryitemsByItineraryBooking.addAll( buildServices(service) ); 
        }
      }
    }

    //--------------------------------------------------------------
    // Core validation and DML methods
    //--------------------------------------------------------------
    private void commitHeaders(){

      try{
        Database.insert(primaryAccount);
        primaryAccount = [select Id, PersonContactId from Account where Id =: primaryAccount.Id];
        
        itinerary.KaptioTravel__Account__c = primaryAccount.Id;
        itinerary.KaptioTravel__Primary_Contact__c = primaryAccount.PersonContactId;
        Database.insert(itinerary);
        
        itinerary.KaptioTravel__Booking__c = true;
        Database.update(itinerary);
        
        itinerary = [select Id, KaptioTravel__BookingNumber__c, KaptioTravel__Booking__c from KaptioTravel__Itinerary__c where Id =: itinerary.Id limit 1];
        
        for(KaptioTravel__Passenger__c pax : passengersByIndex.values()){
          pax.KaptioTravel__Itinerary__c = itinerary.Id;
        }
        Database.insert(passengersByIndex.values());

      } catch(Exception e){
        throw new OnlineBookingFactoryException('exception caught when saving boooking: ' + e.getMessage());
      }
    }

    public void commitLines(){
      try{
        packageBooking.KaptioTravel__Itinerary__c = itinerary.Id;
        packageBooking.KaptioTravel__PackageName__c = pkg.Name;
        Database.insert(packageBooking);

        List<KaptioTravel__ItineraryBooking__c> itineraryBookingsToInsert = new List<KaptioTravel__ItineraryBooking__c>();
        for(ItineraryItemsByItineraryBooking bookingWrapper : itineraryitemsByItineraryBooking){
          bookingWrapper.booking.KaptioTravel__Itinerary__c = itinerary.Id;
          bookingWrapper.booking.KaptioTravel__ItineraryBooking__c = packageBooking.Id;
          itineraryBookingsToInsert.add(bookingWrapper.booking);
        }
        Database.insert(itineraryBookingsToInsert);

        List<KaptioTravel__Itinerary_Item__c> itineraryItemsToInsert = new List<KaptioTravel__Itinerary_Item__c>();
        for(ItineraryItemsByItineraryBooking bookingWrapper : itineraryitemsByItineraryBooking){
          for(KaptioTravel__Itinerary_Item__c itineraryItem : bookingWrapper.itineraryItems){
            itineraryItem.KaptioTravel__Itinerary__c = itinerary.Id;
            itineraryItem.KaptioTravel__ItineraryBooking__c = bookingWrapper.booking.Id;
            itineraryItemsToInsert.add(itineraryItem);
          }
        }
                system.debug(itineraryItemsToInsert);
        Database.insert(itineraryItemsToInsert);
        
        if(payment != null){
          payment.KaptioTravel__Itinerary__c = itinerary.Id;
          Database.insert(payment);
        }

        if(request.mode.equals('production'))
          KaptioTravel.GlobalInventoryService.itineraryItemsRecheckInventory(new Map<Id, SObject>(itineraryItemsToInsert).keySet());

      } catch(Exception e){
        throw new OnlineBookingFactoryException('exception caught when saving boooking: ' + e.getMessage());
      }
    }

    private void validate(){
      if (channel == null)
        throw new OnlineBookingFactoryException(String.format('channel_id {0} not found.', 
          new List<String>{request.channel_id}));
      
      if (pkg == null)
        throw new OnlineBookingFactoryException(String.format('package_code {0} not found.', 
          new List<String>{request.package_booking.parameters.package_code}));
      
      if (request.passengers.isEmpty())
        throw new OnlineBookingFactoryException('No passengers defined. Booking requires at least 1 passenger');

      if (sailing == null && !System.test.isRunningTest() )
        throw new OnlineBookingFactoryException(String.format('sailing on {0} for package {1} not found.', 
          new List<String>{request.package_booking.parameters.booking_date,
            request.package_booking.parameters.package_code}));
    }

    //--------------------------------------------------------------
    // Query and collection helpers
    //--------------------------------------------------------------

    private Map<Integer, Price> buildPriceByIndex(){
      Map<Integer, Price> output = new Map<Integer, Price>();
      for(PricesByIndex index : request.package_booking.prices_by_index){
        output.put(index.index, index.price);
      }
      return output;
    }

    private KaptioTravel__BoardBasis__c getBoardBasis(){
      List<KaptioTravel__BoardBasis__c> boardbasis = [select Id from KaptioTravel__BoardBasis__c 
        where KaptioTravel__Sort__c = 3];
      return boardbasis.isEmpty() ? null : boardbasis[0];
    }
    
    private KaptioTravel__ComponentOption__c getAllInclusivePackageOption(){
    	List<KaptioTravel__ComponentOption__c> allInclusivePackageOption = new List<KaptioTravel__ComponentOption__c>();
    	if (boardbasis != null)
    		allInclusivePackageOption = [SELECT Id FROM KaptioTravel__ComponentOption__c 
    		                             WHERE KaptioTravel__BoardBasis__c =: boardbasis.Id AND PackageName__c =: pkg.Name];
    	return allInclusivePackageOption.isEmpty() ? null : allInclusivePackageOption[0];
    }

    private String getProductType(String package_code){
      String output = '';
      if( package_code.contains('DANUBE_11') ) output = '11 day Danube';
      else if( package_code.contains('RHINE_11B') ) output = '11 day Rhine with Paris';
      else if( package_code.contains('RHINE_11A') ) output = '11 day Rhine without Paris';
      else if( package_code.contains('DANUBE_8') ) output = '8 day Danube';
      else if( package_code.contains('RHINE_8') ) output = '8 day Rhine';

      return output;
    }


    private KaptioTravel__Channel__c getChannel(String channel_id){
      List<KaptioTravel__Channel__c> channels = [select Id from KaptioTravel__Channel__c 
        where Id =: channel_id OR KaptioTravel__ChannelCode__c =: channel_id limit 1];
      return channels.isEmpty() ? null : channels[0];
    }

    private KaptioTravel__Package__c getPackage(String package_code){
      List<KaptioTravel__Package__c> packages = [select Id, Name, CruiseRouteVariation__c, KaptioTravel__Length__c from KaptioTravel__Package__c 
        where ExternalCode__c =: package_code limit 1];
      return packages.isEmpty() ? null : packages[0];
    }

    private Sailing__c getSailing(){
      Date sailingDate = Date.valueOf(request.package_booking.parameters.booking_date);
      List<Sailing__c> sailings = [select Id, CruiseRouteVariation__c from Sailing__c where CruiseRouteVariation__c =: pkg.CruiseRouteVariation__c and DepartureDate__c =: sailingDate limit 1];
      return sailings.isEmpty() ? null : sailings[0];
    }

    private Map<String, KaptioTravel__Component__c> getPackageComponentsByCode(){
      Map<String, KaptioTravel__Component__c> output = new Map<String, KaptioTravel__Component__c>();
      if(pkg != null){
        List<KaptioTravel__Component__c> components = [select Id, 
          ExternalCode__c, 
          (SELECT Id, 
            ExternalCode__c, 
            KaptioTravel__Component__c,
            KaptioTravel__Item__c,
            KaptioTravel__Item__r.KaptioTravel__TaxGroup__c,
            KaptioTravel__Item__r.KaptioTravel__Supplier__c,
            KaptioTravel__Item__r.KaptioTravel__ExternalName__c,
            KaptioTravel__PriceCategory__c,
            KaptioTravel__PriceCategory__r.KaptioTravel__ExternalName__c
            from KaptioTravel__ComponentOptions__r 
            where ExternalCode__c != null) 
          FROM KaptioTravel__Component__c 
          WHERE KaptioTravel__Package__c =: pkg.Id 
          AND ExternalCode__c != null 
          AND ExternalCode__c != 'EXPERIENCES'];
        
        for(KaptioTravel__Component__c component : components){
          output.put(component.ExternalCode__c, component);
        }
      }
      return output;
    }

    //--------------------------------------------------------------
    // Builders
    //--------------------------------------------------------------

    private Account buildPrimaryAccount(Passengers firstPax){
      /*Name, Surname, Passport Number, Phone Number, email, Address */
      RecordType personAccount = [select id from RecordType 
        where IsPersonType = true and SobjectType = 'account' limit 1];
      return new Account(
        RecordType = personAccount, 
        FirstName = firstPax.name,
        LastName = firstPax.surname,
        PersonEmail = firstPax.email,
        Phone = firstPax.phone_number
        // Todo: map other pax fields;
      );
    }

    private KaptioTravel__Itinerary__c buildItinerary(){
      String bookingSource = request.booking_source;
      String campaignCode = request.campaign_code;
      Id campaignId;
      if (campaignCode != null){
      	List<Campaign> campaignList = new List<Campaign>();
      	campaignList = [SELECT Id FROM Campaign WHERE CampaignCode__c =: campaignCode];
      	if (campaignList.size() != 0)
      		campaignId = campaignList.get(0).Id;
      }
      if(bookingSource == null) bookingSource = 'Desktop Website';
      return new KaptioTravel__Itinerary__c(
      	Campaign_Code__c = campaignCode,
      	Campaign__c = campaignId,
        KaptioTravel__Channel__c = channel.Id,
        KaptioTravel__Group_Size__c = request.package_booking.parameters.total_people,
        Sailing__c = sailing.Id,
        CurrencyIsoCode = 'CNY',
        Itinerary_Type__c = bookingSource,
        Product_Type__C = getProductType(request.package_booking.parameters.package_code),
        Name = String.format('{0}{1} on {2} (online booking)', 
          new List<String>{
            request.mode.equals('test') ? 'TEST  ' : '',
            request.package_booking.parameters.package_code, 
            request.package_booking.parameters.booking_date
          }),
        KaptioTravel__Start_Date__c = Date.valueOf(request.package_booking.parameters.booking_date),
        KaptioTravel__End_Date__c = pkg.KaptioTravel__Length__c != null 
                                  ? Date.valueOf(request.package_booking.parameters.booking_date).addDays(Integer.valueOf(pkg.KaptioTravel__Length__c)) 
                                  : Date.valueOf(request.package_booking.parameters.booking_date).addDays(1)
      );
    }

    private KaptioTravel__ItineraryBooking__c buildPackageBooking(){
      return new KaptioTravel__ItineraryBooking__c(
        KaptioTravel__Package__c = pkg.Id,
        KaptioTravel__IsPackageBooking__c = true,
        KaptioTravel__RoomsDetailsJSON__c = JSON.serialize(rooms)
      );
    }

    private Map<Integer, KaptioTravel__Passenger__c> buildPassengersByIndex(List<Passengers> passengers){
      Map<Integer, KaptioTravel__Passenger__c> output = new Map<Integer, KaptioTravel__Passenger__c>();
      for(Passengers passenger : passengers){
        output.put(passenger.index, new KaptioTravel__Passenger__c(
          KaptioTravel__FirstName__c = passenger.name,
          KaptioTravel__LastName__c = passenger.surname,
          KaptioTravel__Gender__c = passenger.gender,
          Birthdate__c = Date.valueOf(passenger.date_of_birth),
          Passport_No__c = passenger.passport_number,
          // TODO Phone__c = passenger.phone_number -- missing from db!,
          // TODO Address = passenger.email -- missing form db!,
          KaptioTravel__Email__c = passenger.email
        ));
      }
      return output;
    }

    private List<ItineraryItemsByItineraryBooking> buildServices(Cabins service){
      List<ItineraryItemsByItineraryBooking> output = new List<ItineraryItemsByItineraryBooking>();
      
      KaptioTravel__Component__c component = packageComponentsByCode.containsKey(service.component_code) ? packageComponentsByCode.get(service.component_code) : null;
      if (component == null) 
        throw new OnlineBookingFactoryException(String.format('"{0}" component does not exist', 
          new List<String>{service.component_code}));
      
      Map<String, SObject> optionsByCode = KaptioUtils.buildSObjectMapByStringKey(component.KaptioTravel__ComponentOptions__r, 'ExternalCode__c');
      for(Selection selection : service.selection){
        
        Integer quantity = service.component_code.equals('ACCOMMODATION') ? 1 : selection.guests;
        if(quantity == null || quantity == 0) throw new OnlineBookingFactoryException(String.format('"guest" parameter for selection is not valid for "{0}". Value is set to "{1}"', new List<String>{selection.item_option_code, String.valueOf(selection.guests)}));

        KaptioTravel__ComponentOption__c option = optionsByCode.containsKey(selection.item_option_code) ? (KaptioTravel__ComponentOption__c)optionsByCode.get(selection.item_option_code) : null;
        if (option == null) throw new OnlineBookingFactoryException(String.format('"{0}" component option does not exist', new List<String>{selection.item_option_code}));
        
        Price selectionPrice = priceByIndex.containsKey(selection.index) ? priceByIndex.get(selection.index) : null;
        if(selectionPrice == null) throw new OnlineBookingFactoryException(String.format('price for "{0}" index "{1}" is not included in payload', new List<String>{selection.item_option_code, String.valueOf(selection.index)}));

        KaptioTravel__Itinerary_Item__c itineraryItem = buildItineraryItem(quantity, option, selectionPrice);
          system.debug(LoggingLevel.Error, JSON.serialize(itineraryItem));
        if (service.component_code.equals('ACCOMMODATION')){
          rooms.add(new RoomDto(rooms.size(), selection.guests, 0));
          // TODO: Other promotion handling!
                    if (boardbasis != null) {
            			itineraryItem.KaptioTravel__BoardBasis__c = boardbasis.Id;
            			if (allInclusivePackageOption != null)
            				itineraryItem.KaptioTravel__PackageComponentSubOption__c = allInclusivePackageOption.Id;
                    }
                    if (itineraryItem.KaptioTravel__DateTo__c != null) {
            itineraryItem.KaptioTravel__DateTo__c += 1;
                    }
        }
        KaptioTravel__ItineraryBooking__c itineraryBooking = buildItineraryBooking(itineraryItem, option);
        ItineraryItemsByItineraryBooking bookingWrapper = new ItineraryItemsByItineraryBooking(itineraryBooking);
        bookingWrapper.itineraryItems.add(itineraryItem);
        output.add(bookingWrapper);
      }
      return output;
    }

    private KaptioTravel__Itinerary_Item__c buildItineraryItem(Integer qty, KaptioTravel__ComponentOption__c option, 
      Price selectionPrice){
                
      return new KaptioTravel__Itinerary_Item__c(
        // Product related
        KaptioTravel__Addon__c = null,
        KaptioTravel__BoardBasis__c = null,
        KaptioTravel__CustomType__c = null,
        KaptioTravel__CustomUOM__c  = null,
        KaptioTravel__Item__c = option.KaptioTravel__Item__c,
        KaptioTravel__Price_Category__c = option.KaptioTravel__PriceCategory__c,
        KaptioTravel__Supplier__c = option.KaptioTravel__Item__r.KaptioTravel__Supplier__c,

        // Booking related
        KaptioTravel__Cancelled__c = false,
        KaptioTravel__DateFrom__c = itinerary.KaptioTravel__Start_Date__c,
        KaptioTravel__DateTo__c = itinerary.KaptioTravel__Start_Date__c,
        KaptioTravel__ExternalName__c = option.KaptioTravel__PriceCategory__r.KaptioTravel__ExternalName__c,
        KaptioTravel__FullName__c = option.KaptioTravel__Item__r.KaptioTravel__ExternalName__c,
        KaptioTravel__IsCustom__c = false,
        KaptioTravel__IsDeleted__c = false,
        KaptioTravel__IsOptional__c = false,
        KaptioTravel__IsVisible__c = true,
        KaptioTravel__Quantity__c = qty,
        KaptioTravel__TimeFrom__c = '12:00',
        KaptioTravel__TimeTo__c = '12:00',

        // Package related
        //KaptioTravel__AddedToPackageTotal__c = true,
        //KaptioTravel__IsPrimaryHoldingPrice__c = false,
        //KaptioTravel__IsSecondaryHoldingPrice__c = false,
        KaptioTravel__PackageComponent__c = option.KaptioTravel__Component__c,
        KaptioTravel__PackageComponentOption__c = option.Id,
        //KaptioTravel__PackageComponentSubOption__c = null, //TODO, review, maybe we can't store the booking like this..

        // Price related
        CurrencyIsoCode = itinerary.CurrencyIsoCode,
        KaptioTravel__CommissionPercent__c = 0,
        KaptioTravel__EstimatedPrice__c = false,
        KaptioTravel__GrossMargin__c = 0, //TODO
        KaptioTravel__ManualCostPrice__c = false,
        KaptioTravel__ManualSellPrice__c = false,
        KaptioTravel__Markup_Percent__c = 0, //todo
        KaptioTravel__OverrideNightDayPricing__c = false,
        KaptioTravel__ProfitMargin__c = 0, //todo
        KaptioTravel__ProfitMarginPercent__c = 0, //todo
        KaptioTravel__RateCodes__c = null,
        KaptioTravel__ResellerCommissionPercent__c = 0,
        KaptioTravel__ResellerCommissionTotal__c = 0,
        KaptioTravel__SupplierBuyRate__c = 1,
        KaptioTravel__SupplierCommissionTotal__c = 0,
        KaptioTravel__SupplierCurrencyIsoCode__c = selectionPrice.supplier_price.currency_iso_code,
        KaptioTravel__SupplierTotalCost__c = Decimal.valueOf(selectionPrice.supplier_price.total),
        KaptioTravel__SupplierUnitCost__c = (Decimal.valueOf(selectionPrice.supplier_price.total) / qty),
        KaptioTravel__Total_Cost__c = Decimal.valueOf(selectionPrice.net),
        KaptioTravel__Total_Price__c = Decimal.valueOf(selectionPrice.sales),
        KaptioTravel__TotalCommission__c = 0,
        KaptioTravel__TotalPriceNet__c = Decimal.valueOf(selectionPrice.sales),
        KaptioTravel__Unit_Cost__c = (Decimal.valueOf(selectionPrice.net) / qty), 
        KaptioTravel__Unit_Price__c = (Decimal.valueOf(selectionPrice.sales) / qty), 
        KaptioTravel__UnitPriceNet__c = (Decimal.valueOf(selectionPrice.sales) / qty), 
        KaptioTravel__Tax_Percent__c = 0,
        KaptioTravel__Tax_Total__c = 0,
        //KaptioTravel__TaxGroupId__c = option.KaptioTravel__Item__r.KaptioTravel__TaxGroup__c,

        // Fullfillment related
        KaptioTravel__AllotmentAction__c = 'Book'
        //KaptioTravel__AllotmentStatus__c 
        //KaptioTravel__AllotmentStatusId__c 
        //KaptioTravel__ConfirmationStatus__c 
        //KaptioTravel__ConfirmationStatusId__c 
        //KaptioTravel__InventoryJSON__c 
        //KaptioTravel__InventoryStatus__c 
        //KaptioTravel__InventoryStatusId__c 
      );
    }

    private KaptioTravel__ItineraryBooking__c buildItineraryBooking(KaptioTravel__Itinerary_Item__c itineraryItem, 
      KaptioTravel__ComponentOption__c option){
      return new KaptioTravel__ItineraryBooking__c(
        KaptioTravel__Component__c = option.KaptioTravel__Component__c,
        KaptioTravel__DateFrom__c = itineraryItem.KaptioTravel__DateFrom__c,
        KaptioTravel__DateTo__c = itineraryItem.KaptioTravel__DateTo__c,
        KaptioTravel__GrossMargin__c = 0, //Todo
        KaptioTravel__IsPackageBooking__c = true,
        KaptioTravel__Item__c = itineraryItem.KaptioTravel__Item__c,
        KaptioTravel__MarkupPercent__c = 0, // todo
        KaptioTravel__Package__c = pkg.Id,
        KaptioTravel__PackageDescription__c = null,
        KaptioTravel__PackageName__c = null,
        KaptioTravel__PackagePriceJSON__c = null,
        KaptioTravel__ProfitMargin__c = 0,
        KaptioTravel__ProfitMarginPercent__c = 0,
        KaptioTravel__ResellerCommissionPercent__c = 0,
        KaptioTravel__ResellerCommissionTotal__c = 0,
        KaptioTravel__RoomsDetailsJSON__c = null,
        KaptioTravel__Subtotal__c = 0,
        KaptioTravel__Supplier__c = itineraryItem.KaptioTravel__Supplier__c,
        KaptioTravel__SupplierCurrencyIsoCode__c = itineraryItem.KaptioTravel__SupplierCurrencyIsoCode__c,
        KaptioTravel__TimeFrom__c = itineraryItem.KaptioTravel__TimeFrom__c,
        KaptioTravel__TimeTo__c = itineraryItem.KaptioTravel__TimeTo__c,
        KaptioTravel__TotalCommission__c = 0,
        KaptioTravel__TotalNetPrice__c = 0,
        KaptioTravel__TotalNetPriceDiscount__c = 0,
        KaptioTravel__TotalSalesPrice__c = 0,
        KaptioTravel__TotalSalesPriceDiscount__c = 0,
        KaptioTravel__TotalSalesPriceNet__c = 0,
        KaptioTravel__TotalSupplierPrice__c = 0,
        KaptioTravel__TotalSupplierPriceDiscount__c = 0
      );
    }
  }

  public static KaptioTravel__Transaction__c buildPayment(Payment payment){
    if(payment != null){
      return new KaptioTravel__Transaction__c(
        KaptioTravel__PayerName__c = payment.payer_name,
        KaptioTravel__PayerEmail__c = payment.payer_email,
        KaptioTravel__Payment_Received_DateTime__c = (Datetime)JSON.deserialize(
          '"' + payment.payment_datetime + '"' , Datetime.class),
        KaptioTravel__PaymentInfo__c = payment.additional_info,
        KaptioTravel__PaymentMethod__c = payment.method,
        KaptioTravel__Amount__c = Decimal.valueOf(payment.amount),
        KaptioTravel__Surcharge__c = Decimal.valueOf(payment.surcharge)
      );
      
    } else {
      return null;
    }
  }

  //--------------------------------------------------------------
  // JSON Parser!
  //--------------------------------------------------------------

  public class BookingRequest {
    public String mode;
    public String booking_source;
    public String currency_iso_code;
    public String channel_id;
    public List<Passengers> passengers;
    public Payment payment;
    public PackageBooking package_booking;
    public String campaign_code;
  }

  public class Passengers {
    public Integer index;
    public String name;
    public String surname;
    public String gender;
    public String date_of_birth;
    public String passport_number;
    public String phone_number;
    public String email;
    public String address; 
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
    public Parameters parameters;
    public List<PricesByIndex> prices_by_index;
    public TotalPrice total_price;
  }

  public class Parameters {
    public String package_code;
    public String booking_date;
    public Integer total_people;
    public List<List<Cabins>> cabins;
  }

  public class Cabins {
    public String component_code;
    public List<Selection> selection;
  }

  public class Selection {
    public Integer index;
    public Integer guests;
    public List<Integer> passenger_indices;
    public String item_option_code;
  }

  public class PricesByIndex {
    public Integer index;
    public Price price;
  }

  public class Price {
    public String net;
    public String sales;
    public String net_discount;
    public String sales_discount;
    public String tax;
    public String currency_iso_code;
    public SupplierPrice supplier_price;
  }

  public class SupplierPrice {
    public String currency_iso_code;
    public String total;
  }

  public class TotalPrice {
    public SupplierPrice supplier_price;
    public String currency_iso_code;
    public String sales_discount;
    public String net_discount;
    public String sales;
    public String net;
    public String tax;
  }

  private static BookingRequest parse(String json) {
    return (BookingRequest) System.JSON.deserialize(json, BookingRequest.class);
  }


  private class ItineraryItemsByItineraryBooking {

    private KaptioTravel__ItineraryBooking__c booking;
    private List<KaptioTravel__Itinerary_Item__c> itineraryItems;

    public ItineraryItemsByItineraryBooking(KaptioTravel__ItineraryBooking__c booking){
      this.booking = booking;
      this.itineraryItems = new List<KaptioTravel__Itinerary_Item__c>();
    }
  }

  private class RoomDto{
    private Integer roomNumber { get; set; }
    private Integer adults { get; set; }
    private Integer children { get; set; }

    private RoomDto(Integer p_roomNumber, Integer p_adults, Integer p_children) {
      roomNumber = p_roomNumber;
      adults = p_adults;
      children = p_children;
    }
  }

  public class OnlineBookingFactoryException extends Exception {}
}