/**
 * Created by maxim on 6/15/18.
 */

trigger OnWebBookings on KaptioTravel__WebBooking__c (after insert) {
	
	if (Trigger.isAfter && Trigger.isInsert) {
		
		for (KaptioTravel__WebBooking__c booking : Trigger.new) {
			new OnlineBookingFactory(booking.KaptioTravel__JSONBody__c, booking.KaptioTravel__Itinerary__c, booking.Id);
		}
	}
}