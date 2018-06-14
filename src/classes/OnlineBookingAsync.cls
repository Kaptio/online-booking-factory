/**
 * @author Ragnar Fjolnisson
 * @date 23/07/2017
 * @description Async job for parts of the online booking factory class
 *
**/
public with sharing class OnlineBookingAsync implements Queueable, Database.AllowsCallouts{

	private OnlineBookingFactory.BookingHelper helper;

	public OnlineBookingAsync(OnlineBookingFactory.BookingHelper helper) {
		this.helper = helper;
	}

	public void execute(QueueableContext context) {
		helper.commitLines();
	}
}