import { describe, expect, it } from 'vitest'
import { draftBillLines, invoiceBillLines, shipmentChargeLines } from '../src/shared/invoiceLines'
const shipment={charge:5000,bookedKg:2,chargeRate:1500,chargeCurrency:'BDT',pricingRates:{BDT:1,CNY:20},customsTax:100,afterSalesFee:50,pcsItems:[{category:'Mobile',count:2,rate:50,currency:'CNY'}]}
describe('shipment invoice breakdown',()=>{
 it('itemizes weight and pieces using saved currencies/rates and reconciles adjustments',()=>{
  const lines=draftBillLines(shipment)
  expect(lines).toEqual([{label:'Shipping · 2 kg × BDT 1,500.00',amount:3000},{label:'Mobile · 2 pcs × CNY 50.00',amount:2000},{label:'Customs tax',amount:100},{label:'After-sales credit',amount:-50}])
  expect(lines.reduce((sum,line)=>sum+line.amount,0)).toBe(5050)
 })
 it('uses weighed weight when it matches the recorded charge',()=>{
  const lines=shipmentChargeLines({...shipment,weighedKg:3,charge:6500})
  expect(lines[0]).toEqual({label:'Shipping · 3 kg × BDT 1,500.00',amount:4500})
 })
 it('does not invent rates or change inconsistent historical amounts',()=>{
  expect(shipmentChargeLines({...shipment,charge:4500})).toEqual([{label:'Shipment charges',amount:4500}])
  expect(shipmentChargeLines({...shipment,pricingRates:{}})).toEqual([{label:'Shipment charges',amount:5000}])
 })
 it('expands a matching automatic line once without repeating billed expenses',()=>{
  const lines=invoiceBillLines({...shipment,invoice:{lines:[{label:'Shipment charges',amount:5000},{label:'Courier charge',amount:120}]}})
  expect(lines).toHaveLength(3)
  expect(lines.reduce((sum,line)=>sum+line.amount,0)).toBe(5120)
 })
 it('preserves edited invoice lines and discounts independently of current shipment pricing',()=>{
  const lines=[{label:'Agreed freight',amount:4200},{label:'Packaging charge',amount:80}]
  expect(invoiceBillLines({...shipment,invoice:{lines}})).toEqual(lines)
 })
})
