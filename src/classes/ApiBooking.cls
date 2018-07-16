/**
 * @author Ragnar Fjolnisson
 * @date 17/06/2017 (Icelandic National Independence day)
 * @description Class to submit bookings
 *
**/
@RestResource(urlMapping='/api/v1.0/submit_booking')
global with sharing class ApiBooking {

	@HttpPost
	global static Response submit() {

		String jsonString = RestContext.request.requestBody.toString();
		try {
			OnlineBookingFactory.BookingRequest request = (OnlineBookingFactory.BookingRequest) System.JSON.deserialize(jsonString, OnlineBookingFactory.BookingRequest.class);

			//Create new or select existing Person Account.
			Account personAccount = buildPersonAccount(request.passengers.get(0));

			//Create Itinerary with Booking Number.
			KaptioTravel__Itinerary__c itinerary = buildItinerary(request, personAccount.Id);

			//Select Itinerary with Booking Number.
			itinerary = [SELECT KaptioTravel__BookingNumber__c FROM KaptioTravel__Itinerary__c WHERE Id = :itinerary.Id LIMIT 1];

			//Create WebBooking__c with jsonString.
			insert new KaptioTravel__WebBooking__c(
				KaptioTravel__Status__c = 'Not Started',
				KaptioTravel__JSONBody__c = jsonString,
				KaptioTravel__Itinerary__c = itinerary.Id
			);

			RestContext.response.addHeader('Content-Type', 'application/json');
			return new Response(itinerary);
		} catch(Exception e) {
			return new Response(e);
		}
	}

	private static Account buildPersonAccount(OnlineBookingFactory.Passenger p_firstPassenger) {
		Id personAccountId = Schema.SobjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
		List<Account> accounts = [
			SELECT Id
			FROM Account
			WHERE FirstName = :p_firstPassenger.first_name
				AND LastName = :p_firstPassenger.last_name
				AND PersonEmail = :p_firstPassenger.email
				AND RecordTypeId = :personAccountId
			LIMIT 1
		];
		Account personAccount = new Account();
		if (accounts.isEmpty()) {
			personAccount = new Account(
				FirstName = p_firstPassenger.first_name,
				LastName = p_firstPassenger.last_name,
				PersonEmail = p_firstPassenger.email,
				RecordTypeId = personAccountId
			);
			insert personAccount;
		} else {
			personAccount = accounts.get(0);
		}
		return personAccount;
	}

	private static KaptioTravel__Itinerary__c buildItinerary(OnlineBookingFactory.BookingRequest p_request, Id p_personAccountId) {

		Account primaryAccount = [
			SELECT PersonContactId
			FROM Account
			WHERE Id = :p_personAccountId
			LIMIT 1
		];

		Date startDate;
		Date endDate;

		if (p_request.package_bookings != null) {
			for (OnlineBookingFactory.PackageBooking booking : p_request.package_bookings) {
				if (startDate == null || (startDate != null && startDate > Date.valueOf(booking.booking_date))) {
					startDate = Date.valueOf(booking.booking_date);
				}

				if (endDate == null || (endDate != null && endDate < Date.valueOf(booking.booking_date))) {
					endDate = Date.valueOf(booking.booking_date);
				}
			}
		}

		if (p_request.single_service_bookings != null) {
			for (OnlineBookingFactory.ServiceBooking booking : p_request.single_service_bookings) {
				for (OnlineBookingFactory.Selection selection : booking.selections) {
					if (startDate == null || (startDate != null && startDate > Date.valueOf(selection.date_from))) {
						startDate = Date.valueOf(selection.date_from);
					}

					if (endDate == null || (endDate != null && endDate > Date.valueOf(selection.date_to))) {
						endDate = Date.valueOf(selection.date_to);
					}
				}
			}
		}
		
		KaptioTravel__Itinerary__c itinerary = new KaptioTravel__Itinerary__c(
			Name = String.format('{0} Itinerary on {1} (online booking)',
				new List<String>{
					p_request.mode.equalsIgnoreCase('test') ? 'TEST  ' : '',
					String.valueOf(Date.today())
				}),
			CurrencyIsoCode = p_request.currency_iso_code,
			KaptioTravel__Account__c = p_personAccountId,
			KaptioTravel__Primary_Contact__c = primaryAccount.PersonContactId,
			KaptioTravel__Channel__c = p_request.channel_id,
			KaptioTravel__Group_Size__c = p_request.passengers.size(),
			KaptioTravel__Start_Date__c = startDate,
			KaptioTravel__End_Date__c = endDate,
			KaptioTravel__Booking__c = true
		);
		insert itinerary;
		return itinerary;
	}

	global class Response {
		public Id itinerary_id;
		public String booking_number;
		public String status;
		public String message;

		public Response(KaptioTravel__Itinerary__c itinerary) {
			this.itinerary_id = itinerary.Id;
			this.booking_number = itinerary.KaptioTravel__BookingNumber__c;
			this.status = '200';
			this.message = 'SUCCESS';
		}

		public Response(Exception e) {
			this.itinerary_id = null;
			this.booking_number = null;
			this.status = '400';
			this.message = e.getMessage() + ' Stack Trace: ' + e.getStackTraceString();
		}
	}
}