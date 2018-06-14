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
        try{
          OnlineBookingFactory f = new OnlineBookingFactory(jsonString);
          RestContext.response.addHeader('Content-Type', 'application/json');
          return new Response(f.helper.itinerary);
      
        } catch(Exception e ){
            KaptioUtils.insertOnlineBookingRequestException('submit-booking', e);
        return new Response(e);
        
        } finally {
            // Create a backup of the json being submitted before any other logic gets applied
            KaptioUtils.insertOnlineBookingRequestBackup('submit-booking', jsonString);
        }
    }

    global class Response {
      public Id itinerary_id;
      public String booking_number;
      public String status;
      public String message;

      public Response(KaptioTravel__Itinerary__c itinerary){
      this.itinerary_id = itinerary.Id;
      this.booking_number = itinerary.KaptioTravel__BookingNumber__c;
      this.status = '200';
      this.message = 'SUCCESS';
      }
      
      public Response(Exception e){
        this.itinerary_id = null;
        this.booking_number = null;
        this.status = '400';
        this.message = e.getMessage();
      }
    }
}