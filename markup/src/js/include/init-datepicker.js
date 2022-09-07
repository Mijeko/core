import 'air-datepicker';

// не для реакта
$('.js-datepicker').datepicker({
    range: false,
    showEvent: 'click',
    onSelect: function onSelect(formattedDate, date, inst) {
        inst.hide();
    }
});
