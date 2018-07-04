# OnlineBookingFactory for Kaptio Travel
Starter code for Online Booking Processing into the WebBooking__c object in Kaptio Travel.

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png)](https://githubsfdeploy.herokuapp.com?owner=Kaptio&repo=online-booking-factory)
*Requires Kaptio Travel 2018 June Major or higher*

## Consumer Flow
Thet OnlineBookingFactory class supports the submission of packages or single-items booking into the Kaptio Travel managed package. The typical transaction flow of for Search-To-Booking and how the is as follows:

1. **Search:** Consumer searches for bookable packages or items via [Kaptio API](http://api.kaptio.com/) (see /item or /package endpoints)
2. **Configuration:**  Consumer configures booking components (option selection, date, time and quantity)
3. **Booking Data Capture:** Consumer provides required information in order to process the booking (passenger data, billing info etc)
4. **Payment Capture:** Depending on the requirements, consumer might be directed to a payment page where card data is collected and deposit or full balnace payment capture is completed. 
5. **Submit Booking**. The final step, and the most relevant to the OnlineBookingFactory, is the submission of the booking back into Kaptio Travel via the [rest relay endpoint](http://api.kaptio.com/static/swagger-ui/#!/tools/post_v1_0_rest_relay). This is where the booking gets initially staged in the KaptioTravel__WebBooking__c queue before it gets processed as a KaptioTravel__Itinerary__c record.

## About Rest Relay Service

Purpose of a the /apexrest relay service is to give consumers with ktapi access the ability to submit to a endpoint that gets relayed back into their specific Salesforce environment. 

As the kttapi is already authenticated back into the customer org we are able to take a request posted to the /apexrest service and relay it it to [Apex REST API](https://developer.salesforce.com/page/Creating_REST_APIs_using_Apex_REST) endpoint. This allows both Kaptio and customers to build custom services in Apex that are executable via KTAPI. This also means that developers can use one authentication token for a full Kaptio + Salesforce API experience.

## ApiBooking class
This library contains the ApiBooking class which is a global Apex Rest class that becomes accessible via Relay via the following POST endpoint: /apexrest/submit_booking/v1/[[channelId]]

The ApiBooking class pushes the request into the OnlineBookingFactory class. The ApiBooking class is meant to be "dumb" and not understand the requirements or context of the OnlineBookingFactory, i.e only passing along the data.

## OnlineBookingFactory 

Once a customer has his single service and/or package selections, provided passenger information and made payments, we can push the booking into Kaptio Travel. The OnlineBookingFactory performs validations while preparing a response. 

This class actually processes the booking. It is meant to be customised for each environment as different data is captured. This library contains as a base foundation for a request/response mechanism but can easily be customised on a per-org basis by adding new parameters and additional mapping.

The pipeline for how the base foundation works is:
1. Consumer pushes JSON request into [KTAPI relay service](http://api.kaptio.com/static/swagger-ui/#!/tools/post_v1_0_rest_relay)
2. KTAPI Relays it to the REST enabled ApiBooking class
3. ApiBooking passes the JSON data along into the OnlineBookingFactory
4. OnlineBookingFactory stages the request into KaptioTravel__WebBooking__c, and starts processing the KaptioTravel__Itinerary__c Header where we get a Booking number for the Response that the ApiBooking class provides back to the consumer.
5. In a seperate apex transaction (to avoid hitting apex memory and query limits), the OnlineBookingFactory inserts the individual services, verifies the prices and books any inventory/allotments needed. If there are errors or data inconsistancies (such as a different price then was submitted by the API), those errors will be noted in the KaptioTravel__WebBooking__c staging record.

## Base Class Model

### Passengers

* `passengers` list has to contain at least 1x entity. All parameters are required.
* `index`  is currently not used but reserved for future functionality where passengers could be allocated into a booking selection (for example` “passenger_allocation” : "1,2"` where 1,2 represent passengers indexed 1 and 2 
* `type` determines the passenger role. List of passenger roles is managed within Kaptio's App Settings (visible under Kaptio > Kaptio Travel Settings > App Settings > Passenger Roles). This parameter is currently not used but reserved for passenger role dependent pricing, for example children and infant pricing.

### Payments

* `payments` list is optional. All parameters are required.
* `method` is a string value representing a method determined under Channels in KaptioTravel App Settings. There is no validation for this parameter.
* `amount` represents the payment amount without a surcharge
* `surcharge` represents a surcharge that may get added to a payment as part of a payment gateway transaction.

### Package Booking

* `package_bookings` list is required if `single_service_bookings` list is empty . All parameters are required.
* The `components` , `selection` and` prices_by_index` objects represent the same objects as the `/packages/{packageId}/prices` service from KTAPI returns in its response. 
* Currently we don't support changing the dates of a component selection so the booking gets inserted as defined on the component level in Kaptio. There is capacity to add this support, in a similar manner as on `single_service_bookings`

### Single Service Bookings

* `single_service_bookings` list is required if package_bookings list is empty . All parameters are required.
* Follows the same principal behaviour as `package_bookings` with `selection`, `index` and `prices_by_index` in addition to  the date fields on `selection`
* `date_to` is only used for multi-day items (accommodation, car rental etc) and can be set to null for single-day items.

```
{
    "_comment": "mode support test and production. test does not reserve inventory or allow for invoices to be posted",
    "mode" : "test",
    "currency": "EUR",
    "channel_code": "B2C-FIT",
    "passengers": [{
        "index": 1,
        "salutation": "Mr",
        "first_name": "Steve",
        "last_name": "Lukather",
        "gender": "male",
        "type": "adult",
        "age": 43
    }, {
        "index": 2,
        "salutation": "Ms",
        "first_name": "Stevie",
        "last_name": "Nicks",
        "gender": "female",
        "type": "adult",
        "age": 43
    }],
    "payment": {
        "index": 1,
        "payer_name": "Rick Davies",
        "payer_email": "rickie@outlook.com",
        "payment_datetime": "2016-11-04T09:30:57.000+0000",
        "additional_info": "transaction 83984",
        "method": "stripe-visa",
        "amount": "17973.00",
        "surcharge": "0.00",
    },
    "package_bookings": [{
        "id": "a0h58000000i9FSAAY",
        "date": "2017-10-22",
        "total_people": 4,
        "total_price": {
            "currency": "EUR",
            "net": "1920.00",
            "net_discount": "0.00",
            "sales": "2540.00",
            "sales_discount": "0",
            "supplier_price": null,
            "tax": "405.56"
        },
        "components": [{
            "component_id": "a0958000000x7msAAA",
            "selection": [{
                "guests": 3,
                "index": 1,
                "item_type_option_id": "a04580000048KO9AAM",
                "item_option_id": "a0p580000015l04AAA",
            }, {
                "guests": 1,
                "index": 2,
                "item_type_option_id": "a04580000048KO9AAM",
                "item_option_id": "a0p580000015l04AAA"
            }]
        }, {
            "component_id": "a0958000001MjxpAAC",
            "selection": [{
                "guests": 4,
                "index": 3,
                "item_type_option_id": null,
                "item_option_id": "a0p58000001WILpAAO"
            }]
        }],
        "prices_by_index": [{
            "price": {
                "supplier_price": {
                    "currency_iso_code": "EUR",
                    "total": "700.00"
                },
                "net_discount": "0.00",
                "currency": "EUR",
                "sales_discount": "0",
                "tax": "147.86",
                "net": "700.00",
                "sales": "926.04"
            },
            "index": 1
        }, {
            "price": {
                "supplier_price": {
                    "currency_iso_code": "EUR",
                    "total": "700.00"
                },
                "net_discount": "0.00",
                "currency": "EUR",
                "sales_discount": "0",
                "tax": "147.86",
                "net": "700.00",
                "sales": "926.04"
            },
            "index": 2
        }, {
            "price": {
                "supplier_price": {
                    "currency_iso_code": "EUR",
                    "total": "520.00"
                },
                "net_discount": "0.00",
                "currency": "EUR",
                "sales_discount": "0",
                "tax": "109.84",
                "net": "520.00",
                "sales": "687.92"
            },
            "index": 3
        }]
    }],
    "single_service_bookings": [{
        "selection": [{
            "guests": 2,
            "index": 0,
            "item_option_id": "a0p58000001WILpAAO",
            "item_type_option_id": null,
            "date_from" : "2017-10-22",
            "date_to" : "2017-10-23",
        }, {
            "guests": 1,
            "index": 1,
            "item_option_id": "a0p58000001WILpAAO",
            "item_type_option_id": null,
            "date_from" : "2017-10-22",
            "date_to" : null
        }],
        "prices_by_index": [{
            "price": {
                "supplier_price": {
                    "currency_iso_code": "EUR",
                    "total": "520.00"
                },
                "net_discount": "0.00",
                "currency": "EUR",
                "sales_discount": "0",
                "tax": "109.84",
                "net": "520.00",
                "sales": "687.92"
            },
            "index": 0
        }, {
            "price": {
                "supplier_price": {
                    "currency_iso_code": "EUR",
                    "total": "520.00"
                },
                "net_discount": "0.00",
                "currency": "EUR",
                "sales_discount": "0",
                "tax": "109.84",
                "net": "520.00",
                "sales": "687.92"
            },
            "index": 1
        }]
    }]
}
```

## Response Class (Status 200)

A response returns a itinerary id from Kaptio as well as a booking number.

```
{
  "results": {
    "itinerary_id": "a0958000000x7msAAA",
    "booking_number": "0-123151"
  }
}
```

## Feedback
Any questions or feedback please submit a ticket on help.kaptio.com
