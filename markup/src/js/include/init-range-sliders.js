import $ from 'jquery';
// window.$ = window.jQuery = $.noConflict();
window.$ = window.jQuery = $;

var slider = require('ion-rangeslider');

window.$ = window.jQuery = $.noConflict();

document.addEventListener('DOMContentLoaded', () => {
    let inputs = [
        document.querySelector('#js-filter-from'),
        document.querySelector('#js-filter-to'),
    ];

    $(".filter-catalog__range").ionRangeSlider({
        skin: "round",
        type: "double",
        min: 0,
        max: 10000,
        hide_min_max: true,
        hide_from_to: true,
        onStart: function (data) {
            // inputs[0].value = data.from;
            // inputs[1].value = data.to;
        },
        onChange: function (data) {
            inputs[0].value = data.from;
            inputs[1].value = data.to;
        },
        onFinish: function (data) {
        },
        onUpdate: function (data) {
        }
    });


//     let bonusInput = document.querySelector('#order-bonus');
// // let bonusInput = document.querySelector('#js-bonus-input');
//     let object = $(".js-select-user-bonus");
//     if (object && bonusInput) {
//         object.ionRangeSlider({
//             min: object.data('min'),
//             max: object.data('max'),
//             from: object.data('from'),
//             onStart: function (data) {
//                 bonusInput.value = data.from;
//             },
//             onChange: function (data) {
//                 bonusInput.value = data.from;
//             },
//         });
//     }
});
